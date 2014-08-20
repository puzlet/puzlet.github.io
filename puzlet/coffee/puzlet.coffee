# TODO:
# @var?
# *** Option to reload => remove old resource?
# BUG: multiple html nodes - all have same id
# pageTitle: for first wiky only
# CreateResource: null ok?
# Support blab subfolder resources => can't just detect / in name.
# coffee compile: do external first; then blabs.
# superclass method: add tag to head?

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
	
	constructor: (@blab, @render, @done) ->
		@resources = new Resources
		@loadCoreResources => @getGist => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce => @done()
	
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
			listResources = JSON.parse list.content
			@resources.add({url: url} for url in listResources)
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
	
	# Async load js and coffee; and py/m:
	#   * external js via <script>; auto-appended to dom, and run.
	#   * blab js and all coffee via ajax; auto-appended to dom (inline) after *all* js/coffee loaded.
	#   * py/m via ajax; no action loading.
	# After all scripts loaded: 
	#   * compile each coffee file, with post-js processing if not #!vanilla.
	#   * append JS (blab js or compiled coffee) to dom: external js (from coffee) first, then current blab js.
	# coffee and blab js available as source to be edited in browser.
	# (Loading scripts after HTML/CSS improves html rendering speed.)
	# Note: for large JS file (even 3rd party), put in repo without gh-pages (web page).
	loadScripts: (callback) ->
		@resources.load ["js", "coffee", "py", "m"], =>
			@compileCoffee()
			callback?()
			
	loadAce: (callback) ->
		load = (resources, callback) =>
			@resources.add resources
			@resources.load ["js", "css"], => callback?()
		new Ace.Resources load, callback
		$(document).on "saveGist", => @saveGist()
	
	saveGist: ->
		
		console.log "Save to anonymous Gist"
		
		resources = @resources.select (resource) ->
			resource.spec.location is "blab"
		files = {}
		files[resource.url] = {content: resource.content} for resource in resources
		
		ajaxData =
			description: document.title
			public: false
			files: files
		$.ajax({
			type: "POST"
			url: "https://api.github.com/gists"
			data: JSON.stringify(ajaxData)
			success: (data) ->
				console.log "Created gist", data.html_url, data
				blabUrl = "?gist="+data.id  # data.html_url
				window.location = blabUrl
				#$(document.body).prepend "<a href='#{blabUrl}' target='_blank'>Saved as Gist</a><br>"
				#alert "Gist: #{data.html_url}"
			dataType: "json"
		})
		
	getGist: (callback) ->
		@gistId = @getGistId()
		unless @gistId
			@gistData = null
			callback?()
			return
		# For https://gist.github.com/:id
		url = "https://api.github.com/gists/#{@gistId}"
		$.get(url, (@gistData) =>
			@resources.setGistResources @gistData.files
			callback?()
		)
		
	getGistId: ->
		query = location.search.slice(1)
		return null unless query
		h = query.split "&"
		p = h?[0].split "="
		gist = if p.length and p[0] is "gist" then p[1] else null
		
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
		
	empty: ->
		@container.empty()
	
	render: (wikyHtml) ->
		@mainContainer() unless @container?
		@container.append Wiky.toHtml(wikyHtml)
		@pageTitle wikyHtml  # ZZZ should work only for first wikyHtml
		
	ready: (@resources, @gistId) ->
		findResource = (url) => @resources.find url
		new Ace.Editors findResource
		new Ace.Evals findResource # CoffeeScript Eval boxes
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new FavIcon
		new GithubRibbon @container, @blab, @gistId
		
	rerender: ->
		@empty()
		@render html.content for html in @resources.select("html")
		new Ace.Editors (url) => @resources.find url
		$(document).trigger "htmlOutputUpdated"
	
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
	
	constructor: (@container, @blab, @gistId) ->
		
		link = if @gistId then "https://gist.github.com/#{@gistId}" else "https://github.com/puzlet/#{@blab}"
		src = "https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67"
		html = """
			<a href="#{link}" id="ribbon" style="opacity:0.2">
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

init = ->
	window.$pz = {}
	window.$blab = {}  # Exported interface.
	window.console = {} unless window.console?
	window.console.log = (->) unless window.console.log?
	$blab.codeDecoration = true
	blab = window.location.pathname.split("/")[1]  # ZZZ more robust way?
	return unless blab and blab isnt "puzlet.github.io"
	page = new Page blab
	render = (wikyHtml) -> page.render wikyHtml
	ready = -> page.ready loader.resources, loader.gistId
	loader = new Loader blab, render, ready
	$pz.renderHtml = -> page.rerender()

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

