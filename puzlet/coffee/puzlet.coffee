window.$pz = {}
window.$blab = {}  # Exported interface.

class MathJaxProcessor
	
	source: "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default"
		# default, TeX-AMS-MML_SVG, TeX-AMS-MML_HTMLorMML
	#outputSelector: ".code_node_html_output"
	mode: "HTML-CSS"  # HTML-CSS, SVG, or NativeMML
	
	constructor: ->  # ZZZ param via mode?
	
		#return # DEBUG
		
		@outputId = "codeout_html"
		
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
	
	# Works:
	# switch, class
	# block comments set $blab.evaluator, but not processed because comment.
	
	# What's not supported:
	# unindented block string literals
	# unindented objects literals not assigned to variable (sees fields as different objects but perhaps this is correct?)
	# Destructuring assignments may not work for objects
	# ZZZ Any other closing chars (like parens) to exclude?
	
	noEvalStrings: [")", "]", "}", "\"\"\"", "else", "try", "catch", "finally", "alert", "console.log"]  # ZZZ better name?
	lf: "\n"
	
	# Class properties.
	@compile = (code, bare=false) ->
		CoffeeEvaluator.blabCoffee ?= new BlabCoffee
		js = CoffeeEvaluator.blabCoffee.compile code, bare
	
	@eval = (code, js=null) ->
		# Pass js if don't want to recompile
		#start = new Date().getTime() / 1000
		#console.log "Start compile"
		js = CoffeeEvaluator.compile code unless js
		#finish1 = new Date().getTime() / 1000
		eval js
		#finish2 = new Date().getTime() / 1000
		#console.log "t_compile/t_eval (s)", finish1-start, finish2-start
		js
	
	constructor: ->
		@js = null
	
	process: (code, recompile=true, stringify=true) ->
		compile = recompile or not(@evalLines and @js)
		if compile
			codeLines = code.split @lf
			$blab.evaluator = ((if @isComment(l) and stringify then l else "") for l in codeLines)  # Need global so that CoffeeScript.eval can access it.
			@evalLines = ((if @noEval(l) then "" else "$blab.evaluator[#{n}] = ")+l for l, n in codeLines).join(@lf)
			js = null
		else
			js = @js
			
		try
			#console.log "evalLines", @evalLines
			@js = CoffeeEvaluator.eval @evalLines, js  # Evaluated lines will be assigned to $blab.evaluator.
			#CoffeeScript.eval(evalLines.join "\n")  # Evaluated lines will be assigned to $blab.evaluator.
		catch error
			console.log "eval error", error
			
		return $blab.evaluator unless stringify  # ZZZ perhaps break into 2 steps (separate calls): process then stringify?
		#result = ("" for e in $blab.evaluator)  # DEBUG
		result = ((if e is "" then "" else (if e and e.length and e[0] is "#" then e else @objEval(e))) for e in $blab.evaluator)
#		result = ((if e is "" then "" else (if e and e.length and e[0] is "#" then e else @objEval(e))) for e in $blab.evaluator)
	
	noEval: (l) ->
		# ZZZ check tabs?
		return true if (l is null) or (l is "") or (l.length is 0) or (l[0] is " ") or (l[0] is "#") or (l.indexOf("#;") isnt -1)
		# ZZZ don't need trim for comment?
		for r in @noEvalStrings
			return true if l.indexOf(r) is 0
		false
	
	isComment: (l) ->
		return l.length and l[0] is "#" and (l.length<3 or l[0..2] isnt "###")
	
	objEval: (e) ->
		#setMax = false
		try
			#start = new Date().getTime() / 1000
			#console.log "obj eval"
			#if setMax
			#	maxProps = 50
			#	numProps = @numProperties e, maxProps
				#console.log "objEval", numProps, e
			#	if numProps>maxProps
			#		objClass = Object.prototype.toString.call(e).slice(8, -1)
			#		return (if objClass is "Array" then "[Array]" else "[Object]")
			line = $inspect2(e, {depth: 2})
			finish1 = new Date().getTime() / 1000
			#console.log "obj eval done", finish1-start
			# line = $inspect(e)
			line = line.replace(/(\r\n|\n|\r)/gm,"")
			return line
		catch error
			return ""
	
window.CoffeeEvaluator = CoffeeEvaluator


class Resources
	
	resourcesClass: "lab_resources"
	
	# ZZZ how do we know when all resources loaded?
	constructor: (@spec, @callback) ->
		#super @spec
		@head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
		@evaluator = new CoffeeEvaluator
		
	process: ->
		
		@removeResources()
		
		@resourcesToLoad = 0
		
		resources = @eval()
		
		# Return if no resources.
		unless resources
			@callback()
			return
		
		moduleIdRegEx = /^[a-z0-9]{5}?(\.[0-9]+|)$/
		# ZZZ also need better match for js/css URL
		
		@wait = false
		for r in resources
			# ZZZ method for this?
			if not r or typeof r isnt "string"
				resourceHtml = null  # ignore these lines
			else if r.match moduleIdRegEx
				t = new Date().getTime()
				prefix = "/#{r}/"
				postfix = "&t=#{t}"
				@addCoffee(prefix + "main.coffee" + postfix)
				@addCss(prefix + "main.css" + postfix)
				l = "/m/#{r}"
			else if r.indexOf(".js") isnt -1
				@addScript r
			else if r.indexOf(".css") isnt -1
				@addCss r
			else
				# Invalid resource.
			
		@callback() if not @wait and @resourcesToLoad is 0
		
	removeResources: ->
		resources = $ ".#{@resourcesClass}"
		resources.remove() if resources.length
	
	addCoffee: (url) ->
		@resourcesToLoad++
		$.ajax(
			url: url
			type: "get"
		).done (data) =>
			CoffeeEvaluator.eval data
			@resourceLoaded()
	
	# Used only for custom JavaScript - not used now for compiled CoffeeScript (addCoffee used instead).
	addScript: (url) ->
		@wait = true
		@resourcesToLoad++
		$js = $ "<script>"
			class: @resourcesClass
			type: "text/javascript"
			src: url
			
		js = $js[0]
		js.onload = (=> @resourceLoaded())
		@head.appendChild js
		
	addCss: (url) ->
		# ZZZ note DUP with js - simplify?  superclass?
		@wait = true
		@resourcesToLoad++
		$css = $ "<link>"
			class: @resourcesClass
			rel: "stylesheet"
			type: "text/css"
			href: url
			
		css = $css[0]
		css.onload = (=> @resourceLoaded())
		@head.appendChild css
		
	resourceLoaded: ->
		@resourcesToLoad--
		@callback() if @resourcesToLoad is 0
	
	eval: ->
		return null unless @code()?.trim().length > 0
		recompile = true
		stringify = false
		result = @evaluator.process @code(), recompile, stringify


getBlabId = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null


loadMainCss = (blab) ->
	css = $ "<link>",
		rel: "stylesheet"
		type: "text/css"
		href: "/#{blab}/main.css"
	$(document.head).append css
	
	# Optional:
	# css.load ->
	# css.error ->


loadMainHtml = (blab, callback) ->
	$.get("/#{blab}/main.html", (data) -> callback data)


loadExtrasJs = (blab) ->
	js = $ "<script>", src: "/#{blab}/extras.js"
	$(document.head).append js


loadMainJs = (blab) ->
	js = $ "<script>", src: "/#{blab}/main.js"
	$(document.head).append js


# Not used yet.
getFileDivs = (blab) ->
	#test = $ "div[data-file]"
	#console.log "test", test.attr "data-file"


getBlab = ->
	blab = getBlabId()
	return null unless blab
	loadMainCss blab
	loadMainHtml blab, (data) ->
		#htmlNode()
#		$("#codeout_html").append Wiky.toHtml(data)
#		new MathJaxProcessor
		loadExtrasJs blab
		loadMainJs blab  # Does not yet load resources
		githubForkRibbon blab
	
htmlNode = ->
	html = """
	<div id="code_nodes" data-module-id="">
	<div class="code_node_container" id="code_node_container_html" data-node-id="html" data-filename="main.html">
		<div class="code_node_output_container" id="output_html">
			<div class="code_node_html_output" id="codeout_html"></div>
		</div>
	</div>
	</div>
	"""
	$("#blab_container").append html


githubForkRibbon = (blab) ->
	html = """
	<a href="https://github.com/puzlet/#{blab}" id="ribbon" style="opacity:0.2"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png"></a>
	"""
	$("#blab_container").append(html)
	setTimeout(->
		$("#ribbon").fadeTo(400, 1).fadeTo(400, 0.2)
	, 2000)


init0 = ->
	blab = getBlabId()
	htmlNode()
	loadMainCss blab
	console.log "time0", Date.now()
	$.get("/#{blab}/main.html", (data) -> 
		$("#codeout_html").append Wiky.toHtml(data)
		new MathJaxProcessor
		
	)

init0()

init = (callback) ->
	
	#blab = getBlabId()
	#return null unless blab
	#$.get("/#{blab}/js.html", (data) ->
	js = $ "<script>"
		type: "text/javascript"
		src: "http://puzlet.com/puzlet/php/source.php?pageId=b00bj&file=d3.min.js"

	(js[0]).onload = ->
		console.log "js loaded"
		callback()
	head = document.getElementsByTagName('head')[0] 
	head.appendChild js[0]
	#callback()
	#)


$(document).ready ->
	console.log "time_doc_ready", Date.now()
	Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	init(-> getBlab())
	#getBlab()

