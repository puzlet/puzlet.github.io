window.$pz = {}
window.$blab = {}  # Exported interface.

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
		href: "main.css"
		#href: "/#{blab}/main.css"
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
	
	head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
	$js = $ "<script>"
		type: "text/javascript"
		src: "main.js"
		
	js = $js[0]
	#js.onload = (=> @resourceLoaded())
	head.appendChild js
	return
	
	js = $ "<script>", src: "main.js"
#	js = $ "<script>", src: "/#{blab}/main.js"
	$(document.head).append js


# Not used yet.
getFileDivs = (blab) ->
	#test = $ "div[data-file]"
	#console.log "test", test.attr "data-file"


getBlab = ->
	blab = getBlabId()
	return null unless blab
#	loadMainCss blab
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
	return unless blab
	Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	
	htmlNode()
	loadMainCss blab
	console.log "time0", Date.now()
	loadMainHtml blab, (data) ->
	#$.get("/#{blab}/main.html", (data) -> 
		$("#codeout_html").append Wiky.toHtml(data)
		new MathJaxProcessor
		init ->
		#	loadExtrasJs blab
			loadMainJs blab  # Does not yet load resources
			githubForkRibbon blab

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


initNew = ->
	blab = "cs-intro" # ZZZ Temp
	return unless blab
	Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	
	htmlNode()
	loadMainCss blab
	console.log "time0", Date.now()
	#loadMainHtml blab, (data) ->
	#$.get("/#{blab}/main.html", (data) -> 
	#	$("#codeout_html").append Wiky.toHtml(data)
	new MathJaxProcessor
	init ->
		#loadExtrasJs blab
		loadMainJs blab  # Does not yet load resources
		githubForkRibbon blab	


#init0()
#initNew()

OLDloadJS = (url) ->
	
	head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
	$js = $ "<script>"
		type: "text/javascript"
		src: "main.js"
		
	js = $js[0]
	#js.onload = (=> @resourceLoaded())
	head.appendChild js
	return
	
	js = $ "<script>", src: "main.js"
#	js = $ "<script>", src: "/#{blab}/main.js"
	$(document.head).append js
	


class Resources
	
	# This class does not use jQuery for loading because it can be used to dynamically load jQuery itself.
	
	constructor: (@spec) ->
		@head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
		@load()
		
	load: ->
		
		@resourcesToLoad = 0
		
		resources = @spec.resources
		unless resources
			@spec.loaded()
			return
		
		@wait = false
		for resource in resources
			url = resource.url
			if url.indexOf(".js") isnt -1
				@addScript resource
			else if url.indexOf(".css") isnt -1
				@addCss resource
			else
				# Invalid resource.
			
		@spec.loaded() if not @wait and @resourcesToLoad is 0
	
	addScript: (resource) ->
		# Return if "var" specified, and already exists.
		if window[resource.var]
			console.log "Already loaded", resource
			return
		url = resource.url
		@wait = true
		@resourcesToLoad++
		js = document.createElement "script"
		js.setAttribute "src", url
		js.setAttribute "type", "text/javascript"
		js.setAttribute "class", @spec.resourcesClass
		js.onload = => @resourceLoaded resource
		document.head.appendChild js
		
	addCss: (resource) ->
		url = resource.url
		@wait = true
		@resourcesToLoad++
		css = document.createElement "link"
		css.setAttribute "href", url
		css.setAttribute "rel", "stylesheet"
		css.setAttribute "type", "text/css"
		css.setAttribute "class", @spec.resourcesClass
		css.onload = => @resourceLoaded resource
		document.head.appendChild css
		
	resourceLoaded: (resource) ->
		console.log "Loaded", resource
		@resourcesToLoad--
		@spec.loaded() if @resourcesToLoad is 0
		
	removeAll: (resourcesClass)->
		resources = $ ".#{resourcesClass}"
		resources.remove() if resources.length


loadJS = (url, callback) ->
	# This does not use jQuery because it is also used to load jQuery itself.
	js = document.createElement "script"
	js.setAttribute "src", url
	js.setAttribute "type", "text/javascript"
	js.onload = -> callback()
	document.head.appendChild js

loadJQuery = (callback) ->
	# Returns if jQuery already loaded.
	if jQuery?
		callback()
	else
		loadJS "http://code.jquery.com/jquery-1.8.3.min.js", -> callback()

init1 = ->
	# (Get blab id)
	
	blab =  window.location.pathname.split("/")[1]  # ZZZ more robust way?
	
	load1 = (callback) ->
		spec =
			resources: [
				{url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
				{url: "/puzlet/css/coffeelab.css"}
				{url: "/puzlet/js/wiky.js", var: "Wiky"}
				{url: "/#{blab}/main.css"}
			]
			resourcesClass: "core_resources"
			loaded: -> callback()
		new Resources spec
		
	loadExtras = (callback) ->
		spec =
			resources: [
				{url: "http://puzlet.com/puzlet/php/source.php?pageId=b00bj&file=d3.min.js", var: "d3"}
				{url: "/puzlet/js/numeric-1.2.6.js", var: "numeric"}
				{url: "/puzlet/js/jquery.flot.min.js"}  # var?
			]
			resourcesClass: "extra_resources"
			loaded: -> callback()
		new Resources spec
		
	loadPage = (callback) ->
		$.get("/#{blab}/main.html", (data) -> 
			Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
			container = $ "<div>", id: "blab_container"
			$(document.body).append container
			htmlNode()
			$("#codeout_html").append Wiky.toHtml(data)
			new MathJaxProcessor
			loadExtras ->
				loadMainJs blab  # Does not yet load resources
				githubForkRibbon blab
				callback()
		)
		
	
	#loadJQuery ->
	#	console.log $
	load1 ->
		console.log "Resources loaded"
		loadPage -> console.log "Page loaded"
		
	# First load batch:
	# jQuery
	# /puzlet/css/coffeelab.css
	# /puzlet/js/wiky.js
	# [blab]/main.css
	
	# After these loaded:
	# [blab]/main.html (AJAX)
	# Create html node; wiky.
	# (special) puzlet/images/favicon.ico
	
	# After html loaded/rendered:
	# [blab]/extras, plus:
		# d3 (in extras)
		# jQuery UI (JS)
		# http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css
		# /puzlet/js/numeric-1.2.6.js
		# /puzlet/js/jquery.flot.min.js
		
	# After resources loaded:
	# [blab]/main.js (later, main.coffee)
	# Github ribbon
	
	
	
	
init1()
	


#$(document).ready ->
#	console.log "time_doc_ready", Date.now()
	#Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	#init(-> getBlab())
	#getBlab()

