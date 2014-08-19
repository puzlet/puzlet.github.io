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
		@loadCoreResources => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce => @done()
	
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
		
		resources = @resources.select (resource) -> resource.spec.location is "blab"
		files = {}
		files[resource.url] = {content: resource.content} for resource in resources
		
		#data = {html_url: "puzlet.com"}
		#$(document.body).prepend "<p>Created gist: <a href='#{data.html_url}'>#{data.html_url}</a></p>"
		
		#return
		
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
				$(document.body).prepend "<p>Created gist: <a href='#{data.html_url}' target='_blank'>#{data.html_url}</a></p>"
				#alert "Gist: #{data.html_url}"
			dataType: "json"
		})
		
	getGist: ->
		# Test
		# For https://gist.github.com/anonymous/d766b1f32ab6c2258da2
		url = "https://api.github.com/gists/d766b1f32ab6c2258da2"
		$.get(url, (data) ->
			console.log "gist", data
		)
		
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
		
	ready: (@resources) ->
		new Ace.Editors (url) => @resources.find url
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new FavIcon
		new GithubRibbon @container, @blab
		
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


init = ->
	window.$pz = {}
	window.$blab = {}  # Exported interface.
	window.console = {} unless window.console?
	window.console.log = (->) unless window.console.log?
	blab = window.location.pathname.split("/")[1]  # ZZZ more robust way?
	return unless blab and blab isnt "puzlet.github.io"
	page = new Page blab
	render = (wikyHtml) -> page.render wikyHtml
	ready = -> page.ready loader.resources
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

