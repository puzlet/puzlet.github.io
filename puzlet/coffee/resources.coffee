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
			@createElement()
			#@element.text @content
			callback?()
			
	createElement: ->
		@element = $ "<#{@tag}>",
			type: @mime
			"data-url": @url
		@element.text @content
	
	inDom: ->
		$("#{@tag}[data-url='#{@url}']").length
		
	appendToHead: ->
		@head.appendChild @element[0] unless @inDom()
		
	update: (@content) ->
		@head.removeChild @element[0]
		@createElement()
		@appendToHead()
	
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
			@createElement()
			callback?()
			
	createElement: ->
		@element = $ "<script>",
			type: "text/javascript"
			"data-url": @url
	
	compile: ->
		# ZZZ enhance with try/catch for errors
		js = CoffeeEvaluator.compile @content
		@element.text js
		@head.appendChild @element[0]
		
	update: (@content) ->
		@head.removeChild @element[0]
		@createElement()
		@compile()


class JsonResource extends Resource
	
	load: (callback) -> super callback, "json"


class Resources
	
	# The resource type if based on:
	#   * file extension (html, css, js, coffee, json, py, m)
	#   * url path (in blab or external).
	# Ajax-loaded resources:
	#   * Any resource in current blab.
	#   * html, coffee, json, py, m resources.
	# For ajax-loaded resources, source is available for in-browser editing.
	# All other resources are "linked" resources - loaded via <link href=...> or <script src=...>.
	# load method specifies resources to load (via filter):
	#   * linked resources are appended to DOM as soon as they are loaded.
	#   * ajax-loaded resources (js, css) are appended after all resources loaded (for call to load).
	resourceTypes:
		html: {blab: HtmlResource, ext: HtmlResource}
		css: {blab: CssResourceInline, ext: CssResourceLinked}
		js: {blab: JsResourceInline, ext: JsResourceLinked}
		coffee: {blab: CoffeeResource, ext: CoffeeResource}
		json: {blab: JsonResource, ext: JsonResource}
		py: {blab: Resource, ext: Resource}
		m: {blab: Resource, ext: Resource}
	
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
		
	find: (url) ->
		return resource for resource in @resources when resource.url is url
		return null
