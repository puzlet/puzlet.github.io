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
			console.log "success: "+@url
			@content = data
			@postLoad callback
		document.title = @url if navigator.userAgent.indexOf("iPhone") isnt -1
		t = Date.now()
		$.get(@url+"?t=#{t}", success, type)
			.fail(=>
				console.log "fail "+@url
			)
			.always(=>
				document.title = "get "+@url if navigator.userAgent.indexOf("iPhone") isnt -1
				console.log "get "+@url
			) 
			
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
		
		@style.onload = =>
			console.log "onload "+@url
			@postLoad callback
		@head.appendChild @style
		
		if navigator.userAgent.indexOf("iPhone") isnt -1
			@postLoad callback


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
		@script.onload = =>
			console.log "onload "+@url
			@postLoad callback
		
		t = Date.now()
		@script.setAttribute "src", @url+"?t=#{t}"
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
			console.log "DEC LOAD: "+resourcesToLoad
			if resourcesToLoad is 0
				@appendToHead filter  # Append to head if the appendToHead method exists for a resource, and if not aleady appended.
				loaded?()
		for resource in resources
			resourcesToLoad++
			console.log "INC LOAD: "+resourcesToLoad+" "+resource.url
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
		@loadCoreResources => @loadResourceList => @loadHtmlCss => @loadScripts => @done()
	
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
		document.title = "Puzlet LOAD" if navigator.userAgent.indexOf("iPhone") isnt -1
		@resources.load ["html", "css"], =>
			console.log "html:"+html.content for html in @resources.select("html")
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
		htmlNode = @htmlNode()
		htmlNode.append Wiky.toHtml(wikyHtml)
		@pageTitle wikyHtml  # ZZZ should work only for first wikyHtml
		
	ready: ->
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new FavIcon
		new GithubRibbon @container, @blab
		
	htmlNode: ->
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
		$("#codeout_html")  # ZZZ improve so html constructed via jQuery?  or via template
		
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
	#document.title = "Puzlet - Loading..."
	render = (wikyHtml) -> page.render wikyHtml
	ready = -> page.ready()
	loader = new Loader blab, render, ready

init()


#=== Not used yet ===

#=== RESOURCE EDITING IN BROWSER ===

#--- Viewing/editing/running code in blab page ---
# Code of any file in *current* blab can be viewed in page, by inserting <div> code in main.html (or any html file):
# <div data-file="foo.coffee"></div>

# If this code is edited (and ok/run button pressed), it replaces the previous code (and executes if it's a script).
# Later, we'll support way of saving edited code to gist.

getFileDivs = (blab) ->
	#test = $ "div[data-file]"
	#console.log "test", test.attr "data-file"


getBlabFromQuery = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null


#=== OLD ===

#oldLoader = new OLDLoader blab
#oldLoader.loadCoreResources ->
#	new OLDPage blab, oldLoader, -> console.log "Page loaded"

class OLDResources
	
	# This class does not use jQuery for loading because it can be used to dynamically load jQuery itself.
	
	constructor: (@spec) ->
		@head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
		@resources = @spec.resources
		@load()
		
	load: ->
		
		@resourcesToLoad = 0
		
		resources = @resources
		unless resources
			@spec.loaded()
			return
		
		@wait = false
		#console.log "resources", resources
		for name, resource of resources
			url = resource.url
			#console.log "resource", resource, url
			if resource.ajax
				@addFile resource
			else
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
		t = Date.now()
		js = document.createElement "script"
		js.setAttribute "src", url+"?t=#{t}"
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
		
	addFile: (resource) ->
		# Uses jQuery
		url = resource.url
		@wait = true
		@resourcesToLoad++
		$.get(url, (data) =>
			console.log "^^^^^^^^old get"
			resource.content = data
			@resourceLoaded resource
		)
		
	resourceLoaded: (resource) ->
		console.log "Loaded", resource
		@resourcesToLoad--
		@spec.loaded(@resources) if @resourcesToLoad is 0
		
	removeAll: (resourcesClass)->
		resources = $ ".#{resourcesClass}"
		resources.remove() if resources.length


class OLDLoader
	
	res =
		blab:
			# All have optional "source" property.  source: true means load source via ajax.
			markup: {url: "main.html"}  # Always gets source; assumes Wiky initially
			css: {url: "main.css"}  # optional: source: true
			scripts:
				main: {url: "main.js"}
				foo: {url: "foo.coffee"}
		libraries:
			d3: {url: "d3"}
			numeric: {url: ""}
			flot: {url: ""}
			x: {url: "/blabId/foo.js"}  # Based on path, blabs get loaded after other libraries.
		# What about other library dependecies?
		
	constructor: (@blab) ->
		
	loadCoreResources: (callback) ->
		spec =
			resources:
				jQuery: {url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
				puzletCss: {url: "/puzlet/css/coffeelab.css"}
				Wiky: {url: "/puzlet/js/wiky.js", var: "Wiky"}
			resourcesClass: "core_resources"
			loaded: -> callback()
		new OLDResources spec
		
	loadBlabMarkup: (callback) ->
		spec =
			resources:
				mainHtml: {url: "main.html", ajax: true}
				mainCss: {url: "main.css"}  # No ajax initially
			resourcesClass: "blab_markup_resources"
			loaded: (resources) -> callback(resources)
		new OLDResources spec
		
	loadBlabResourcesFile: (callback) ->
		$.get("resources.json", (data) => callback data)
	
	loadExtras: (callback) ->
		@loadBlabResourcesFile (res) ->
			
			spec =
				resources:
					numeric: {url: "/puzlet/js/numeric-1.2.6.js", var: "numeric"}
					flot: {url: "/puzlet/js/jquery.flot.min.js"}  # var?
					jQueryUiCss: {url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css"}
					jQueryUi: {url: "http://code.jquery.com/ui/1.9.2/jquery-ui.min.js"}
				resourcesClass: "extra_resources"
				loaded: -> callback()
			
			# Append resources specified by resources.json in blab.
			spec.resources["extra"+idx] = {url: r} for r, idx in res  # ZZZ idx is temp
			
			new OLDResources spec
		
	loadMainJs: (callback) ->
		spec =
			resources:
				mainJs: {url: "main.js"}
			resourcesClass: "main_resources"
			loaded: -> callback()
		new OLDResources spec
		
	#loadWiky: (callback) ->
	#	$.get("main.html", (data) => callback data)
		
	loadFavIcon: ->
		icon = $ "<link>"
			rel: "icon"
			type: "image/png"
			href: "/puzlet/images/favicon.ico"
		$(document.head).append icon
	


class OLDPage
	
	# ZZZ what if already rendered?
	
	constructor: (@blab, @loader, @callback) ->
		@loader.loadBlabMarkup (resources) =>
			console.log "blab resources", resources.mainHtml
			wiky = resources.mainHtml.content
			@render wiky
		
	render: (wiky) ->
		Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
		container = $ "<div>"
			id: "blab_container"
		container.hide()
		$(document.body).append container
		@htmlNode container
		$("#codeout_html").append Wiky.toHtml(wiky)
		container.show()
		@pageTitle wiky
		new MathJaxProcessor
		@loader.loadExtras =>
			@loader.loadMainJs =>
				@loader.loadFavIcon()
				@githubForkRibbon @blab
				@callback()
	
	htmlNode: (container) ->
		html = """
		<div id="code_nodes" data-module-id="">
		<div class="code_node_container" id="code_node_container_html" data-node-id="html" data-filename="main.html">
			<div class="code_node_output_container" id="output_html">
				<div class="code_node_html_output" id="codeout_html"></div>
			</div>
		</div>
		</div>
		"""
		container.append html
	
	
	pageTitle: (wiky) ->
		matches = wiky.match /[^|\n][=]{1,6}(.*?)[=]{1,6}[^a-z0-9][\n|$]/
		document.title = matches[1] if matches?.length
	
	githubForkRibbon: ->
		src = "https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67"
		html = """
			<a href="https://github.com/puzlet/#{@blab}" id="ribbon" style="opacity:0.2">
			<img style="position: absolute; top: 0; right: 0; border: 0;" src="#{src}" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png"></a>
		"""
		$("#blab_container").append(html)
		setTimeout (-> $("#ribbon").fadeTo(400, 1).fadeTo(400, 0.2)), 2000




