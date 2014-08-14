# TODO:
# @var?
# *** Option to reload => remove old resource?
# BUG: multiple html nodes - all have same id
# pageTitle: for first wiky only
# CreateResource: null ok?
# Support blab subfolder resources => can't just detect / in name.
# coffee compile: do external first; then blabs.
# superclass method: add tag to head?

class Resource
	
	constructor: (@spec) ->
		# ZZZ option to pass string for url
		@url = @spec.url
		@var = @spec.var  # window variable name  # ZZZ needed here?
		@fileExt = Resource.getFileExt @url
		@loaded = false
		@head = document.head
	
	load: (callback, type="text") ->
		# Default file load method.
		# Uses jQuery.
		success = (data) =>
			@content = data
			@postLoad callback
		t = Date.now()
		$.get(@url+"?t=#{t}", success, type)
			
	postLoad: (callback) ->
		@loaded = true
		callback?()
	
	isType: (type) -> @fileExt is type
	
	@getFileExt: (url) ->
		a = document.createElement "a"
		a.href = url
		fileExt = (a.pathname.match /\.[0-9a-z]+$/i)[0].slice(1)
	
	@typeFilter: (types) ->
		(resource) ->
			if typeof types is "string"
				resource.isType types
			else
				# Array of strings
				for type in types
					return true if resource.isType type
				false


class HtmlResource extends Resource


class ResourceInline extends Resource
	
	# Abstract class.
	# Subclass defines properties tag and mime.
	
	load: (callback) ->
		super =>
			@element = $ "<#{@tag}>",
				type: @mime
				"data-url": @url
			@element.text @content
			callback?()
			
	inDom: ->
		$("#{@tag}[data-url='#{@url}']").length
		
	appendToHead: ->
		@head.appendChild @element[0] unless @inDom()
	
class CssResourceInline extends ResourceInline
	
	tag: "style"
	mime: "text/css"



class CssResourceLinked extends Resource
	
	load: (callback) ->
		@style = document.createElement "link"
		@style.setAttribute "type", "text/css"
		@style.setAttribute "rel", "stylesheet"
		@style.setAttribute "href", @url
		#@style.setAttribute "data-url", @url
		
		# Old browsers (e.g., old iOS) don't support onload for CSS.
		# And so we force postLoad even before CSS loaded.
		# Forcing postLoad generally ok for CSS because won't affect downstream dependencies (unlike JS). 
		setTimeout (=> @postLoad callback), 0
		#@style.onload = => @postLoad callback
		
		@head.appendChild @style


class JsResourceInline extends ResourceInline
	
	tag: "script"
	mime: "text/javascript"


class JsResourceLinked extends Resource
	
	load: (callback) ->
		if @var and window[@var]
			console.log "Already loaded", @url
			# ZZZ postload?
			return
		@wait = true
		@script = document.createElement "script"
		@script.setAttribute "type", "text/javascript"
		@head.appendChild @script
		@script.onload = => @postLoad callback
		
		t = Date.now()
		# ZZZ need better way to handle caching
		cache = @url.indexOf("/puzlet/js") isnt -1 or @url.indexOf("http://") isnt -1
		@script.setAttribute "src", @url+(if cache then "" else "?t=#{t}")
		#@script.setAttribute "data-url", @url


class CoffeeResource extends Resource
	
	load: (callback) ->
		super =>
			@element = $ "<script>",
				type: "text/javascript"
				"data-url": @url
			callback?()
	
	compile: ->
		# Alternative: CoffeeEvaluator.eval
		js = CoffeeEvaluator.compile @content
		@element.text js
		@head.appendChild @element[0]


class JsonResource extends Resource
	
	load: (callback) -> super callback, "json"


class Resources
	
	# The resource type if based on:
	#   * file extension (html, css, js, coffee, json)
	#   * url path (in blab or external).
	# Ajax-loaded resources:
	#   * Any resource in current blab.
	#   * html, coffee, json resources.
	# For ajax-loaded resources, source is available for in-browser editing.
	# All other resources are "linked" resources - loaded via <link href=...> or <script src=...>.
	# load method specifies resources to load (via filter):
	#   * linked resources are appended to DOM as soon as they are loaded.
	#   * ajax-loaded resources are appended after all resources loaded (for call to load).
	resourceTypes:
		html: {blab: HtmlResource, ext: HtmlResource}
		css: {blab: CssResourceInline, ext: CssResourceLinked}
		js: {blab: JsResourceInline, ext: JsResourceLinked}
		coffee: {blab: CoffeeResource, ext: CoffeeResource}
		json: {blab: JsonResource, ext: JsonResource}
	
	constructor: ->
		@resources = []
	
	add: (resourceSpecs) ->
		resourceSpecs = [resourceSpecs] unless resourceSpecs.length
		newResources = []
		for spec in resourceSpecs
			resource = @createResource spec
			newResources.push resource
			@resources.push resource
		if newResources.length is 1 then newResources[0] else newResources
		
	createResource: (spec) ->
		url = spec.url
		fileExt = Resource.getFileExt url
		location = if url.indexOf("/") is -1 then "blab" else "ext"
		spec.location = location  # Needed for coffee compiling
		if @resourceTypes[fileExt] then new @resourceTypes[fileExt][location](spec) else null
	
	load: (filter, loaded) ->
		# When are resources added to DOM?
		#   * Linked resources: as soon as they are loaded.
		#   * Inline resources (with appendToHead method): *after* all resources are loaded.
		filter = @filterFunction filter
		resources = @select((resource) -> not resource.loaded and filter(resource))
		if resources.length is 0
			loaded?()
			return
		resourcesToLoad = 0
		resourceLoaded = (resource) =>
			resourcesToLoad--
			if resourcesToLoad is 0
				@appendToHead filter  # Append to head if the appendToHead method exists for a resource, and if not aleady appended.
				loaded?()
		for resource in resources
			resourcesToLoad++
			resource.load -> resourceLoaded(resource)
	
	loadUnloaded: (loaded) ->
		# Loads all unloaded resources.
		@load (-> true), loaded
		
	appendToHead: (filter) ->
		filter = @filterFunction filter
		resources = @select((resource) -> not resource.inDom?() and resource.appendToHead? and filter(resource))
		resource.appendToHead() for resource in resources
		
	select: (filter) ->
		filter = @filterFunction filter
		(resource for resource in @resources when filter(resource))
		
	filterFunction: (filter) ->
		if typeof filter is "function" then filter else Resource.typeFilter(filter)


class Loader
	
	#--- Example resources.json ---
	# Note that order is important for html rendering order, css cascade order, and script execution order.
	# But blab resources can go at top because always loaded after external resources.
	###
	[
		"main.html",
		"style.css",
		"bar.js",
		"foo.coffee",
		"main.coffee",
		"/some-repo/snippet.html",
		"/other-repo/foo.css",
		"/puzlet/js/d3.min.js",
		"http://domain.com/script.js",
		"/ode-fixed/ode.coffee"
	]
	###
	
	coreResources: [
		{url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
		{url: "/puzlet/js/wiky.js", var: "Wiky"}
	]
	
	resourcesList: {url: "resources.json"}
	
	htmlResources: [
		{url: "/puzlet/css/coffeelab.css"}
		{url: "/puzlet/css/ace.css"}
	]
	
	scriptResources: [
		{url: "/puzlet/js/coffeescript.js"}
		{url: "/puzlet/js/acorn.js"}
		{url: "/puzlet/js/numeric-1.2.6.js"}
		{url: "/puzlet/js/compile.js"}
	]
	# {url: "/puzlet/js/jquery.flot.min.js"}
	# {url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css"}
	# {url: "http://code.jquery.com/ui/1.9.2/jquery-ui.min.js"}
	
	aceResources1: [
		{url: "/puzlet/js/ace4/ace.js"}
	]
	
	aceResources2: [
		{url: "/puzlet/js/ace4/mode-coffee.js"}
		{url: "/puzlet/js/ace4/mode-python.js"}
		{url: "/puzlet/js/ace4/mode-matlab.js"}
		{url: "/puzlet/js/ace4/mode-latex.js"}
	]
	
	constructor: (@blab, @render, @done) ->
		@resources = new Resources
		@loadCoreResources => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce1 => @loadAce2 => @done()
	
	# Dynamically load and run jQuery and Wiky.
	loadCoreResources: (callback) ->
		@resources.add @coreResources
		@resources.loadUnloaded callback
		
	# Load and parse resources.json.  (Need jQuery to do this; uses ajax $.get.)
	# Get ordered list of resources (html, css, js, coffee).
	# Prepend /puzlet/css/puzlet.css to list; prepend script resources (CoffeeScript compiler; math).
	loadResourceList: (callback) ->
		list = @resources.add @resourcesList
		@resources.loadUnloaded => 
			@resources.add @htmlResources
			@resources.add @scriptResources
			@resources.add({url: url} for url in list.content)
			callback?()
	
	# Async load html and css:
	#   * all html via ajax.
	#   * external css via <link>; auto-appended to dom as soon as resource loaded.
	#   * blab css via ajax; auto-appended to dom (inline) after *all* html/css loaded.
	# After all html/css loaded, render html via Wiky.
	# html and blab css available as source to be edited in browser.
	loadHtmlCss: (callback) ->
		@resources.load ["html", "css"], =>
			@render html.content for html in @resources.select("html")
			callback?()
	
	# Async load js and coffee:
	#   * external js via <script>; auto-appended to dom, and run.
	#   * blab js and all coffee via ajax; auto-appended to dom (inline) after *all* js/coffee loaded.
	# After all scripts loaded: 
	#   * compile each coffee file, with post-js processing if not #!vanilla.
	#   * append JS (blab js or compiled coffee) to dom: external js (from coffee) first, then current blab js.
	# coffee and blab js available as source to be edited in browser.
	# (Loading scripts after HTML/CSS improves html rendering speed.)
	# Note: for large JS file (even 3rd party), put in repo without gh-pages (web page).
	loadScripts: (callback) ->
		@resources.load ["js", "coffee"], =>
			@compileCoffee()
			callback?()
			
	loadAce1: (callback) ->
		@resources.add @aceResources1
		@resources.load "js", => callback?()
	
	loadAce2: (callback) ->
		@resources.add @aceResources2
		@resources.load "js", =>
			#console.log "Ace loaded"
			callback?()
	
	compileCoffee: ->
		# ZZZ do external first; then blabs.
		coffee.compile() for coffee in @resources.select "coffee"


class Page
	
	constructor: (@blab) ->
	
	mainContainer: ->
		return if @container?
		@container = $ "<div>", id: "blab_container"
		@container.hide()
		$(document.body).append @container
		@container.show()  # ZZZ should show only after all html rendered - need another event.
	
	render: (wikyHtml) ->
		@mainContainer() unless @container?
		#htmlNode = @htmlNode()
		@container.append Wiky.toHtml(wikyHtml)
		@pageTitle wikyHtml  # ZZZ should work only for first wikyHtml
		
	ready: (@resources) ->
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new FavIcon
		@processCodeNodes()
		new GithubRibbon @container, @blab
		
	processCodeNodes: ->
		#console.log "resources", @resources
		codeNodes = $ "div[data-file]"
		findCode = (filename) =>
			#console.log "filename", filename
			for resource in @resources.resources
				#console.log resource
				url = resource.url
				return resource if url is filename
			return null
		for n in codeNodes
			node = $ n
			filename = node.attr "data-file"
			resource = findCode filename
			new CodeNode node, resource if resource
		initAce()  # ZZZ make method?
		
	htmlNode: ->
		# ZZZ no longer used.
		html = """
		<div id="code_nodes" data-module-id="">
		<div class="code_node_container" id="code_node_container_html" data-node-id="html" data-filename="main.html">
			<div class="code_node_output_container" id="output_html">
				<div class="code_node_html_output" id="codeout_html"></div>
			</div>
		</div>
		</div>
		"""
		@container.append html
		$("#codeout_html")
		
	pageTitle: (wikyHtml) ->
		matches = wikyHtml.match /[^|\n][=]{1,6}(.*?)[=]{1,6}[^a-z0-9][\n|$]/
		document.title = matches[1] if matches?.length


class FavIcon
	
	constructor: ->
		icon = $ "<link>"
			rel: "icon"
			type: "image/png"
			href: "/puzlet/images/favicon.ico"
		$(document.head).append icon


class GithubRibbon
	
	constructor: (@container, @blab) ->
	
		src = "https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67"
		html = """
			<a href="https://github.com/puzlet/#{@blab}" id="ribbon" style="opacity:0.2">
			<img style="position: absolute; top: 0; right: 0; border: 0;" src="#{src}" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png"></a>
		"""
		@container.append(html)
		setTimeout (-> $("#ribbon").fadeTo(400, 1).fadeTo(400, 0.2)), 2000


class MathJaxProcessor
	
	source: "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default"
		# default, TeX-AMS-MML_SVG, TeX-AMS-MML_HTMLorMML
	#outputSelector: ".code_node_html_output"
	mode: "HTML-CSS"  # HTML-CSS, SVG, or NativeMML
	
	constructor: ->  # ZZZ param via mode?
	
		#return # DEBUG
		
		@outputId = "blab_container"
#		@outputId = "codeout_html"
		
		#MathJaxProcessor?.mode = "SVG"
		
		#@mode = "SVG"
		# return if $blab.mathjaxConfig already exists?
		
		$blab.mathjaxConfig = =>
			$.event.trigger "mathjaxPreConfig"
			window.MathJax.Hub.Config
				jax: ["input/TeX", "output/#{@mode}"]
				tex2jax: {inlineMath: [["$", "$"], ["\\(", "\\)"]]}
				TeX: {equationNumbers: {autoNumber: "AMS"}}
				elements: [@outputId, "blab_refs"]
				showProcessingMessages: false
				#"HTML-CSS": {scale: 100}
				MathMenu:
					showRenderer: true
			window.MathJax.HTML.Cookie.Set "menu", renderer: @mode
			#console.log "mathjax", window.MathJax.Hub
		
		configScript = $ "<script>",
			type: "text/x-mathjax-config"
			text: "$blab.mathjaxConfig();"
		mathjax = $ "<script>",
			type: "text/javascript"
			src: @source
		$("head").append(configScript).append(mathjax)
		
		$(document).on "htmlOutputUpdated", => @process()
		
	process: ->
		return unless MathJax?
		@id = @outputId  # Only one node.  ZZZ or do via actual dom element?
		#console.log "mj id", @id
		Hub = MathJax.Hub
		queue = (x) -> Hub.Queue x
		queue ["PreProcess", Hub, @id]
		queue ["Process", Hub, @id]
		configElements = => Hub.config.elements = [@id]
		queue configElements


class CoffeeEvaluator
	
	@compile = (code, bare=false) ->
		CoffeeEvaluator.blabCoffee ?= new BlabCoffee
		js = CoffeeEvaluator.blabCoffee.compile code, bare
		
	@eval = (code, js=null) ->
		# Pass js if don't want to recompile
		js = CoffeeEvaluator.compile code unless js
		eval js
		js


#---------- Ace ----------#

class CodeNode
	
	constructor: (@container, @resource) ->
		#console.log @container, @resource
		@html()
	
	html: ->
		# ZZZ temp
		filename = @resource.url
		id = "code_node_#{filename}"  # ZZZ may need to gen ids?
		codeNodeFilename = filename
		codeNodeLanguage = @resource.fileExt  # ZZZ extract from file
		codeNodeTextAreaContent = @resource.content
		html =
		"""
		<div class="code_node_container" id="code_node_container_#{id}" data-node-id="#{id}" data-filename="#{codeNodeFilename}">
			<div class="code_node_editor_container">
				<div class="code_node_editor" id="ace_editor_#{id}" data-lang="#{codeNodeLanguage}"></div>
			</div>
			<textarea class="code_node_textarea" id="code_node_textarea_#{id}" name="code[]" style="display: none" readonly>#{codeNodeTextAreaContent}</textarea>
		</div>
		
		"""
		@container.append html

class AceModes
	
	constructor: ->
		
		@ace3 = false
		
		@names =
			python: "ace/mode/python"
			octave: if @ace3 then "ace/mode/octave" else "ace/mode/matlab"
			latex: "ace/mode/latex"
			html: "ace/mode/html"
			javascript: "ace/mode/javascript"
			css: "ace/mode/css"
			coffee: "ace/mode/coffee"
			
		@modes = {}
		for lang, mode of @names
			if @ace3
				Mode = require(mode).Mode
				@modes[lang] = new Mode()
			else
				# ace4
				@modes[lang] = mode
			
	
	hasMode: (lang) -> @names.hasOwnProperty lang
	
	getMode: (lang) -> if @hasMode lang then @modes[lang] else null


class CodeNodeSource
	
	constructor: (@codeNodeContainer, @idxInPage) ->
		
		@outer = @codeNodeContainer.find ".code_node_editor_container"  # ZZZ legacy
		@container = @codeNodeContainer.find ".code_node_editor"
		@textarea = @codeNodeContainer.find ".code_node_textarea"
		
		#@codeNodeContainer = @outer.parent()  # outer is editor container; its parent is code node container
		#@codeNodeId = @codeNodeContainer.data "node-id"  # id for <code> node in markup
		@id = @container.attr "id"  # ace editor id (for ace editor to be created)
		@lang = @container.data "lang"
		
		@editor = ace.edit @id
		@editor.setTheme "ace/theme/textmate"
		mode = $pz.aceModes.getMode @lang if @lang
		@session().setMode mode if mode
		@session().setValue @textarea.val()
		
		@initRenderer()
		@initFont()
		@setHeight()
		
		@isEditable = false
		@editor.setReadOnly true
		@renderer.$gutterLayer.setShowLineNumbers false, 1
		
		@editor.setHighlightActiveLine false
		
		@customRendering()
		
		@inFocus = false
		
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
		
		@container.addClass "pz_ace_editor"
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
		@container.css css
		
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
		@container.css("height", heightStr)
		@outer.css("height", heightStr) # ZZZ Is this the best way?
		@editor.resize()
		
	customRendering: ->
		
		@linkSelected = false
		@comments = []
		@functions = []
		
		# Override onFocus method.
		onFocus = @editor.onFocus  # Current onFocus method.
		@editor.onFocus = =>
			@restoreCode()
			# ZZZ issue here?
			onFocus.call @editor
			@renderer.showCursor() if @isEditable
			@renderer.hideCursor() unless @isEditable
			@inFocus = true
			
		onBlur = @editor.onBlur  # Current onBlur method.
		@editor.onBlur = =>
			#console.log "blur", @id
			@renderer.hideCursor()
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
		
	# Temporary until we support module importing (and exporting js) here.
	# This should be done in module code.
	#registerLinks: ->
	#	link = (moduleId, section) -> {href: "/m/#{moduleId}"+(if section then "##{section}" else "")}
	#	$pz.AceIdentifiers.registerLinks
	#		irls: link "b007h"
	#		l1eq_pd: link "b004d"
	#		linsolve: link "b004d"
	#		combnk: link "b0077"
	#		perm_dftmtx: link "b007g", "permuted_dft_matrix"
	#		chipping_matrix: link "b007g", "chipping_matrix"
	#		acc_dump_matrix: link "b007g", "accumulate_and_dump_matrix"
	#		amplitude_vector: link "b007g", "amplitude_vector"
	#		spark: link "b0086"
		
	render: ->
		
		#console.log "render", @id
		
		return unless window.MathJax
		return unless $blab.codeDecoration
		
		#console.log "render"
		
		commentNodes = @container.find ".ace_comment"
		linkCallback = (target) => @linkSelected = target
		@comments = (new CodeNodeComment($(node), linkCallback) for node in commentNodes)
		comment.render() for comment in @comments
		
		#return  # Temp until support rendering of code node function links.
		
		# Identifiers/functions test.
		identifiers = @container.find ".ace_identifier"
		@functions = (new CodeNodeFunction($(i), l, linkCallback) for i in identifiers when l = AceIdentifiers.link($(i).text()))
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
	
	session: -> if @editor then @editor.getSession() else null
	
	code: -> @session().getValue()
	
	show: (show) ->
		@outer.css("display", if show then "" else "none")
	
	showCode: (show) ->
		@editor.show show
		@editor.resize() if show


class AceIdentifiers
	
	@links: {}
	
	@registerLinks: (links) ->
		for identifier, link of links
			AceIdentifiers.links[identifier] = link
	
	@link: (name) ->
		#console.log "links", AceIdentifiers.links, name, AceIdentifiers.links["foo"], AceIdentifiers.links[name], AceIdentifiers.links.length
		AceIdentifiers.links[name]


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
		#console.log "f node", @node
		@originalText = @node.text()
		#wikyOut = Wiky.toHtml(comment)
		@replaceDiv()
#		@mathJax()  # ZZZ not needed?
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



init = ->
	window.$pz = {}
	window.$blab = {}  # Exported interface.
	window.console = {} unless window.console?
	window.console.log = (->) unless window.console.log?
	blab = window.location.pathname.split("/")[1]  # ZZZ more robust way?
	return unless blab and blab isnt "puzlet.github.io"
	page = new Page blab
	render = (wikyHtml) ->
		page.render wikyHtml
	ready = ->
		page.ready loader.resources
		
	loader = new Loader blab, render, ready

initAce = ->
	$pz.AceIdentifiers = AceIdentifiers
	$pz.aceModes = new AceModes
	# Find all code nodes in page.
	codeNodeContainers = $ ".code_node_container"
	#console.log codeNodeContainers
	$pz.codeNode = {}
	for nodeContainer, idxInPage in codeNodeContainers
		$nodeContainer = $(nodeContainer)
		nodeId = $nodeContainer.data "node-id"
		$pz.codeNode[nodeId] = new CodeNodeSource $nodeContainer, idxInPage

init()


#=== Not used yet ===

#=== RESOURCE EDITING IN BROWSER ===

#--- Viewing/editing/running code in blab page ---
# Code of any file in *current* blab can be viewed in page, by inserting <div> code in main.html (or any html file):
# <div data-file="foo.coffee"></div>

# If this code is edited (and ok/run button pressed), it replaces the previous code (and executes if it's a script).
# Later, we'll support way of saving edited code to gist.

getBlabFromQuery = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null

