window.$pz = {}
window.$blab = {}  # Exported interface.

#=== RESOURCE LOADING ===

#---Phase 1: LOAD PUZLET---
# index.html loads puzlet.js.  (<script> tag in a repo's index.html.)

#---Phase 2: CORE LIBRARIES---
# puzlet.js (dynamically) loads and runs jQuery and Wiky.  (Run = append to head.)

#---Phase 3: RESOURCES LIST---
# Load resources.json from blab repo.  (Need jQuery to do this - for ajax $.get.)
# Parse resources.json to get ordered lists of a) html; b) css; c) js; d) coffee.
# Flag each resource as either "blab" (from current blab) or "external" (from another blab or external url).

#---Phase 4: HTML/CSS---
# (Don't load scripts yet; improves html rendering speed.)
# Prepend /puzlet/css/puzlet.css to css list.  (Currently coffeelab.css; needs to be simplified.)
# Async load html (ajax) and css: external css via <link> (auto-appended to dom); blab css via ajax.
# After all html/css loaded:
#   * append blab css to dom (in order).
# 	* create blab_container div; process html via Wiky; append processed html to blab_container, in order.
# html and blab css available as source to be edited in browser.

#---Phase 5: SCRIPTS---
# Prepend to js list: coffeescript.js, acorn.js, numeric.js, compile.js (PaperScript).
# Async load js and coffee: *external* js via <script> (auto-appended to dom, and run); blab js and all coffee via ajax.
# [Typical resources (and order): blab js/coffee, d3, flot, jQuery-UI, imported blab js/coffee.]
# After all scripts loaded: 
#   * compile each coffee file, with post-js processing if not #!vanilla.
#   * append JS (blab js or compiled coffee) to dom: external js (from coffee) first, then current blab js.
# coffee and blab js available as source to be edited in browser.

# Note: for large JS file (even 3rd party), put in repo without gh-pages (web page).

#--- Example resources.json ---
# Note that order is important for html rendering order, css cascade order, and script execution order.
# But blab resources are always loaded after external resources and so can go at top.
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

#--- Viewing/editing/running code in blab page ---
# Code of any file in *current* blab can be viewed in page, by inserting <div> code in main.html (or any html file):
# <div data-file="foo.coffee"></div>

# If this code is edited (and ok/run button pressed), it replaces the previous code (and executes if it's a script).
# Later, we'll support way of saving edited code to gist.

class Resource
	
	constructor: (@spec) ->
		# ZZZ option to pass string for url
		@url = @spec.url
		@var = @spec.var  # window variable name  # ZZZ needed here?
		@fileExt = Resource.getFileExt @url
		@loaded = false
		@head = document.head  # Doesn't work with jQuery.
	
	load: (callback, type="text") ->
		# Default file load method.
		# Uses jQuery.
		@wait = true  # ZZZ how should this be used?
		success = (data) =>
			@content = data
			@postLoad callback
		$.get(@url, success, type)
			
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
	
	# load method from superclass

class CssResourceInline extends Resource
	
	load: (callback) ->
		super =>
			@style = $ "<style>"
				type: "text/css"
				"data-url": @url
			@style.append @content
			callback?()
			
	inDom: ->
		$("style[data-url='#{@url}']").length
			
	appendToHead: ->
		@head.appendChild @style[0] unless @inDom()

class CssResourceLinked extends Resource
	
	load: (callback) ->
		@style = document.createElement "link"
		@style.setAttribute "type", "text/css"
		@style.setAttribute "rel", "stylesheet"
		@style.setAttribute "href", @url
		#@style.setAttribute "data-url", @url
		@style.onload = => @postLoad callback
		@head.appendChild @style

class JsResourceInline extends Resource
	
	load: (callback) ->
		super =>
			@script = $ "<script>"
				type: "text/javascript"
				"data-url": @url
			@script.append @content
			callback?()
			
	inDom: ->
		$("script[data-url='#{@url}']").length
			
	appendToHead: ->
		@head.appendChild @script[0] unless @inDom()

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
		@script.setAttribute "src", @url+"?t=#{t}"
		#@script.setAttribute "data-url", @url
	
class CoffeeResource extends Resource
	
	# load method from superclass
		
class JsonResource extends Resource
	
	load: (callback) -> super callback, "json"


class Resources
	
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
		
		if @resourceTypes[fileExt]
			new @resourceTypes[fileExt][location](spec)
		else
			null  # ZZZ ok?
	
	load: (filter, loaded) ->
		# ZZZ need "wait" here?  use "var" here to not load if already loaded?
		# ZZZ Option to reload => remove old resource?
		
		# When are resources added to DOM?
		#   * Linked resources: as soon as they are loaded.
		#   * Inline resources (with appendToHead method): *after* all resources are loaded.
		filter = @filterFunction filter
		resources = @select((resource) -> not resource.loaded and filter(resource))
		resourcesToLoad = 0
		resourceLoaded = =>
			resourcesToLoad--
			if resourcesToLoad is 0
				@appendToHead filter  # Append to head if the appendToHead method exists for a resource, and if not aleady appended.
				loaded?()
		for resource in resources
			resourcesToLoad++
			resource.load -> resourceLoaded()
				
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


class Loader
	
	coreResources: [
		{url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
		{url: "/puzlet/js/wiky.js", var: "Wiky"}
	]
	
	resourcesList: {url: "resources.json"}
	
	htmlResources: [
		{url: "/puzlet/css/coffeelab.css"}  # ZZZ later, make this puzlet.css
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
	
	loadCoreResources: (callback) ->
		@resources.add @coreResources
		@resources.loadUnloaded callback
		
	loadResourceList: (callback) ->
		list = @resources.add @resourcesList
		@resources.loadUnloaded => 
			@resources.add({url: url} for url in list.content)
			@resources.add @htmlResources
			@resources.add @scriptResources
			callback?()
		
	loadHtmlCss: (callback) ->
		@resources.load ["html", "css"], =>
			@render html.content for html in @resources.select("html")
			callback?()
			
	loadScripts: (callback) ->
		@resources.load ["js", "coffee"], =>
			# ZZZ TODO: coffee
			callback?()

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


class Page
	
	constructor: (@blab) ->
		Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	
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


init = ->
	window.console = {} unless window.console?
	window.console.log = (->) unless window.console.log?
	blab = window.location.pathname.split("/")[1]  # ZZZ more robust way?
	return unless blab and blab isnt "puzlet.github.io"
	#oldLoader = new OLDLoader blab
	#oldLoader.loadCoreResources ->
	#	new OLDPage blab, oldLoader, -> console.log "Page loaded"
	page = new Page
	render = (wikyHtml) -> page.render wikyHtml
	ready = -> page.ready()
	loader = new Loader blab, render, ready
		
	
init()

#test = ->
#	js = "var foo = function() {var z=1; oo(); var y=1;  var bar = function() {oo();};  var zz=1;};\nvar x=1;\nfoo();";
#	js = PaperScript.compile js
#	console.log "js", js
#test()


#=== Not used yet ===

getFileDivs = (blab) ->
	#test = $ "div[data-file]"
	#console.log "test", test.attr "data-file"


getBlabFromQuery = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null


