window.$pz = {}
window.$blab = {}  # Exported interface.

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
	
	constructor: (@blab) ->
		
	loadCoreResources: (callback) ->
		spec =
			resources: [
				{url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
				{url: "/puzlet/css/coffeelab.css"}
				{url: "/puzlet/js/wiky.js", var: "Wiky"}
				{url: "/#{@blab}/main.css"}
			]
			resourcesClass: "core_resources"
			loaded: -> callback()
		new Resources spec
		
	loadBlabResourcesFile: (callback) ->
		$.get("/#{@blab}/resources.json", (data) => callback data)
	
	loadExtras: (callback) ->
		@loadBlabResourcesFile (res) ->
			
			console.log "res", res
			
			spec =
				resources: [
					{url: "/puzlet/js/numeric-1.2.6.js", var: "numeric"}
					{url: "/puzlet/js/jquery.flot.min.js"}  # var?
					{url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css"}
					{url: "http://code.jquery.com/ui/1.9.2/jquery-ui.min.js"}
				]
				resourcesClass: "extra_resources"
				loaded: -> callback()
			
			# Append resources specified by resources.json in blab.
			spec.resources.push {url: r} for r in res
			
			new Resources spec
		
	loadMainJs: (callback) ->
		spec =
			resources: [
				{url: "/#{@blab}/main.js"}
			]
			resourcesClass: "main_resources"
			loaded: -> callback()
		new Resources spec
		
	loadWiky: (callback) ->
		$.get("/#{@blab}/main.html", (data) => callback data)
		
	loadFavIcon: ->
		icon = $ "<link>"
			rel: "icon"
			type: "image/png"
			href: "/puzlet/images/favicon.ico"
		$(document.head).append icon
	


class Page
	
	# ZZZ what if already rendered?
	
	constructor: (@blab, @loader, @callback) ->
		@loader.loadWiky (wiky) => @render wiky 
		
	render: (wiky) ->
		Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
		container = $ "<div>", id: "blab_container"
		$(document.body).append container
		@htmlNode container
		$("#codeout_html").append Wiky.toHtml(wiky)
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
	


init = ->
	window.console = {} unless window.console?
	window.console.log = (->) unless window.console.log?
	blab = window.location.pathname.split("/")[1]  # ZZZ more robust way?
	loader = new Loader blab
	loader.loadCoreResources ->
		new Page blab, loader, -> console.log "Page loaded"
init()


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


