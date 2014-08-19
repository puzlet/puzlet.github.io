Ace = {}

# ZZZ why is $pz.codeNode needed?
class Ace.Editors
	
	constructor: (@findResource) ->
		$pz.AceIdentifiers = Ace.Identifiers
		@containers = $ "div[#{Ace.Editor.fileAttr}]"
		@editors = (@createEditor $(container) for container in @containers)
		$pz.codeNode = {}
		$pz.codeNode[editor.id] = editor for editor in @editors
		
	createEditor: (container) ->
		filename = container.attr Ace.Editor.fileAttr  # ZZZ should fileAttr come from this class?
		resource = @findResource filename
		return null unless resource
		lang = Ace.Languages.langName resource.fileExt
		Editor = Ace.Languages.get(lang).Editor ? Ace.Editor
		spec =
			container: container
			filename: filename
			lang: lang
			code: resource.content
			update: (code) -> resource.update?(code)  # Updates resource code
		new Editor spec


class Ace.Editor
	
	# ZZZ methods to get resource attrs?
	# ZZZ rename container?
	
	@fileAttr: "data-file"
	
	constructor: (@spec) ->
		
		@container = @spec.container
		
		@filename = @spec.filename
		@lang = @spec.lang
		
		@id = "ace_editor_#{@filename}"
		@initContainer()
		
		@editor = ace.edit @id
		@editor.setTheme "ace/theme/textmate"
		mode = Ace.Languages.mode(@lang) if @lang
		@session().setMode mode if mode
		@session().setValue @spec.code
		
		@initRenderer()
		@initFont()
		@setHeight()
		
		@isEditable = false
		@editor.setReadOnly true
		@renderer.$gutterLayer.setShowLineNumbers false, 1
		
		@editor.setHighlightActiveLine false
		
		@enableChangeAction = true
		@session().on "change", =>
			@changeAction() if @enableChangeAction
		@changeListeners = []
		
		@customRendering()
		
		@inFocus = false
		
		@setEditable()
		@keyboardShortcuts()
	
	
	initContainer: ->
		@container.addClass "code_node_container"
		@outer = $ "<div>", class: "code_node_editor_container"  # ZZZ rename?
		@editorContainer = $ "<div>",
			class: "code_node_editor"
			id: @id
			"data-lang": "#{@lang}"
		@outer.append @editorContainer
		@container.append @outer
	
	
	initRenderer: ->
		
		@renderer = @editor.renderer
		
		# Initially no scroll bars
		id = @id
		@renderer.scrollBar.setWidth = (width) ->
			# width and element are properties of renderer
			width = this.width or 15 unless width?
			$(this.element).css("width", width + "px")
		
		@renderer.scrollBar.setWidth 0
		@renderer.scroller.style.overflowX = "hidden"
		#@renderer.$gutter.style.minWidth = "32px";
		#@renderer.$gutter.style.paddingLeft = "5px";
		#@renderer.$gutter.style.paddingRight = "5px";
		
		# If Ace changes line height, update height of editor box.
		# This is always called after body loaded because Ace uses polling approach for character size change.
		@renderer.$textLayer.addEventListener "changeCharacterSize", => @setHeight()
		
		# Note: ace.js had to be edited directly to handle this. See comment "MVC" in ace.js.
		@renderer.$gutterLayer.setShowLineNumbers = (show, start=1) ->
			this.showLineNumbers = show
			this.lineNumberStart = start
	
	
	initFont: ->
		
		# Code node editor is 720px wide
		# Left margin (line numbers + code margin) is ~3 characters
		# Menlo/DejaVu 11pt or Consolas 12pt char width is 9px
		# 77 characters per line (but cutoff at ~75 if v.scrollbar margin)
		# Total chars per editor width: 77+3=80 = 720/9
		
		# To experiment with fonts in puzlet page, use coffee node:
		# puzletInit.register(=> $(".code_node_editor").css css)
		
		# We found that using font-face fonts from google meant that MathJax needed 90% scaling.
		
		@editorContainer.addClass "pz_ace_editor"
		# Fonts do not work via CSS class.
		css =
			fontFamily: "Consolas, Menlo, DejaVu Sans Mono, Monaco, monospace" 
			fontSize: "11pt" 
			lineHeight: "150%"
		char = $ "<span>"
			css: css
			html: "m"
		$("body").append char
		@charWidth = char.width()
		char.remove()
		@narrowFont = @charWidth<9
		css.fontSize = "12pt" if @narrowFont  # For Consolas
		@editorContainer.css css
	
	
	setHeight: ->
		return if not @editor
		lines = @code().split("\n")
		numLines = lines.length
		if numLines<20
			lengths = (l.length for l in lines)
			max = Math.max.apply(Math, lengths)
			numLines++ if max>75
		else
			numLines++
		lineHeight = @renderer.lineHeight
		return if @numLines is numLines and @lineHeight is lineHeight
		
		@numLines = numLines
		@lineHeight = lineHeight
		heightStr = lineHeight * (if numLines>0 then numLines else 1) + "px"
		@editorContainer.css("height", heightStr)
		@outer.css("height", heightStr) # ZZZ Is this the best way?
		@editor.resize()
	
	
	customRendering: ->
		
		@linkSelected = false
		@comments = []
		@functions = []
		
		@editor.setShowFoldWidgets false
		@renderer.$gutterLayer.setShowLineNumbers true, 1
		
		# Override onFocus method.
		onFocus = @editor.onFocus  # Current onFocus method.
		@editor.onFocus = =>
			@restoreCode()
			# ZZZ issue here?
			onFocus.call @editor
			@renderer.showCursor() if @isEditable
			@renderer.hideCursor() unless @isEditable
			@editor.setHighlightActiveLine true #if source.isEditable
			@inFocus = true
			
		onBlur = @editor.onBlur  # Current onBlur method.
		@editor.onBlur = =>
			@renderer.hideCursor()
			@editor.setHighlightActiveLine false
			@render()
			@inFocus = false
			#onBlur.call @editor  # Why is this omitted?
		
		# Comment link navigation etc.
		@editor.on "mouseup", (aceEvent) => @mouseUpHandler()
		
		# ZZZ temporary hack to render function links
		#@registerLinks()
		
		$(document).on "mathjaxPreConfig", =>
			window.MathJax.Hub.Register.StartupHook "MathMenu Ready", =>
				@render()
		
		#@render()
	
	
	render: ->
		
		return unless window.MathJax
		return unless $blab.codeDecoration
		
		commentNodes = @editorContainer.find ".ace_comment"
		linkCallback = (target) => @linkSelected = target
		@comments = (new CodeNodeComment($(node), linkCallback) for node in commentNodes)
		comment.render() for comment in @comments
		
		# Identifiers/functions test.
		identifiers = @editorContainer.find ".ace_identifier"
		@functions = (new CodeNodeFunction($(i), l, linkCallback) for i in identifiers when l = Ace.Identifiers.link($(i).text()))
		f.render() for f in @functions
		# Also should look for class="ace_entity ace_name ace_function"
	
	
	restoreCode: ->
		comment.restore() for comment in @comments
		f.restore() for f in @functions
	
	
	mouseUpHandler: ->
		# Comment link navigation.
		return unless @linkSelected
		href = @linkSelected.attr "href"
		target = @linkSelected.attr "target"
		if target is "_self"
			$(document.body).animate {scrollTop: $(href).offset().top}, 1000
		else
			window.open href, target ? "_blank"
		@linkSelected = false
		@editor.blur()
	
	
	focus: -> 
		@editor.focus()  # ZZZ How is this different from base class focus?
	
	
	session: ->
		if @editor then @editor.getSession() else null
	
	
	code: ->
		@session().getValue()
	
	
	set: (code) ->
		# ZZZ or setCode
		return unless @editor
		@session().setValue code
		@setHeight()
	
	
	show: (show) ->
		@outer.css("display", if show then "" else "none")
	
	
	showCode: (show) ->
		@editor.show show
		@editor.resize() if show
	
	
	setEditable: (editable=true) ->
		@isEditable = editable
		@editor.setReadOnly (not editable)
		@editor.setHighlightActiveLine false
	
	
	changeAction: ->
		@setHeight()  # Resize if code changed.
		code = @code()
		#@spec.change? this
		listener code for listener in @changeListeners
	
	
	onChange: (f) ->
		@changeListeners.push f
	
	
	keyboardShortcuts: ->
		command = (o) => @editor.commands.addCommand o
		command
			name: "run"
			bindKey: 
				win: "Shift-Return"
				mac: "Shift-Return"
				sender: "editor"
			exec: (env, args, request) =>
				#_gaq?.push ["_trackEvent", "runCoffee", "run (key)", $pz?.module.id]
				@spec.update(@code())
		command
			name: "save"
			bindKey:
				win: "Ctrl-s"
				mac: "Ctrl-s"
				sender: "editor"
			exec: (env, args, request) =>
				@spec.update(@code())
				$(document).trigger "saveGist"
	


class CoffeeEditor extends Ace.Editor
	
	constructor: (@spec) ->
		super @spec
		#@setEditable()


class Ace.Languages
	
	@list:
		html: {ext: "html", mode: "html"}
		css: {ext: "css", mode: "css"}
		javascript: {ext: "js", mode: "javascript"}
		coffee: {ext: "coffee", mode: "coffee", Editor: CoffeeEditor}
		json: {ext: "json", mode: "javascript"}
		python: {ext: "py", mode: "python"}
		octave: {ext: "m", mode: "matlab"}
		latex: {ext: "tex", mode: "latex"}
	
	@get: (lang) -> Ace.Languages.list[lang]
	
	@mode: (lang) -> "ace/mode/"+(Ace.Languages.get(lang).mode)
	
	@langName: (ext) ->
		return name for name, language of Ace.Languages.list when language.ext is ext
	


class Ace.Identifiers
	
	@links: {}
	
	@registerLinks: (links) ->
		for identifier, link of links
			Ace.Identifiers.links[identifier] = link
	
	@link: (name) ->
		Ace.Identifiers.links[name]


class CodeNodeComment
	
	# ZZZ: potential bug - dangerous if render twice in row without restore?
	
	constructor: (@node, @linkCallback) ->
		
	render: ->
		@originalText = @node.text()
		#wikyOut = Wiky.toHtml(comment)
		@replaceDiv()
		@mathJax()
		@processLinks()
		
	#saveOriginal: ->
		# ZZZ shouldn't need to save in DOM?
	#	c = "pz_original_comment"
	#	@original = @node.siblings ".#{c}"
	#	@original?.remove()
	#	@original = $ "<div>"  # <span> ?
	#		class: c
	#		css: display: "none"
	#		text: @originalText
	#	@original.insertAfter @node
		
	replaceDiv: ->
		pattern = String.fromCharCode(160)
		re = new RegExp(pattern, "g")
		comment = @originalText.replace(re, " ")
		@node.empty()
		content = $ "<div>", css: display: "inline-block"
		content.append comment
		@node.append content
		
	mathJax: ->
		return unless node = @node[0]
		MathJax.Hub.Queue(["PreProcess", MathJax.Hub, node])
		MathJax.Hub.Queue(["Process", MathJax.Hub, node])
	
	processLinks: ->
		links = @node.find "a"
		return unless links.length
		for link in links
			$(link).mousedown (evt) => @linkCallback $(evt.target)
			
	restore: ->
		if @originalText  # ZZZ call @original ?
			@node.empty()
			@node.text @originalText


class CodeNodeFunction
	# Very similar to above.  Have base class?
	
	constructor: (@node, @link, @linkCallback) ->
		
	render: ->
		@originalText = @node.text()
		#wikyOut = Wiky.toHtml(comment)
		@replaceDiv()
		@processLinks()
		
	replaceDiv: ->
		#pattern = String.fromCharCode(160)  # needed?
		#re = new RegExp(pattern, "g")
		#txt = @originalText.replace(re, " ")
		txt = @originalText
		link = $ "<a>"
			href: @link.href
			target: @link.target
			text: txt
		@node.empty()
		content = $ "<div>", css: display: "inline-block"
		content.append link
		@node.append content
		
	mathJax: ->
		return unless node = @node[0]
		MathJax.Hub.Queue(["PreProcess", MathJax.Hub, node])
		MathJax.Hub.Queue(["Process", MathJax.Hub, node])
	
	processLinks: ->
		links = @node.find "a"
		return unless links.length
		for link in links
			$(link).mousedown (evt) => @linkCallback $(evt.target)
			
	restore: ->
		if @originalText  # ZZZ call @original ?
			@node.empty()
			@node.text @originalText


class Ace.Resources
	
	main: [
		{url: "/puzlet/js/ace4/ace.js"}
	]
	
	modes: [
		{url: "/puzlet/js/ace4/mode-html.js"}
		{url: "/puzlet/js/ace4/mode-css.js"}
		{url: "/puzlet/js/ace4/mode-javascript.js"}
		{url: "/puzlet/js/ace4/mode-coffee.js"}
		{url: "/puzlet/js/ace4/mode-python.js"}
		{url: "/puzlet/js/ace4/mode-matlab.js"}
		{url: "/puzlet/js/ace4/mode-latex.js"}
	]
	
	styles: [
		{url: "/puzlet/css/ace.css"}  # Must be loaded after ace.js
	]
	
	constructor: (load, loaded) ->
		load @main, => load @modes, => load @styles, loaded


