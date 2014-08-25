class Resource
	
	constructor: (@spec) ->
		# ZZZ option to pass string for url
		@url = @spec.url
		@var = @spec.var  # window variable name  # ZZZ needed here?
		@fileExt = @spec.fileExt ? Resource.getFileExt @url
		@loaded = false
		@head = document.head
		@containers = new ResourceContainers this
	
	load: (callback, type="text") ->
		# Default file load method.
		# Uses jQuery.
		if @spec.gistSource
			@content = @spec.gistSource
			@postLoad callback
			return
		success = (data) =>
			@content = data
			@postLoad callback
		t = Date.now()
		$.get(@url+"?t=#{t}", success, type)
			
	postLoad: (callback) ->
		@loaded = true
		callback?()
	
	isType: (type) -> @fileExt is type
	
	update: (@content) ->
		console.log "No update method for #{@url}"
		
	hasEval: -> @containers.evals().length
	
	render: -> @containers.render()
	
	getEvalContainer: -> @containers.getEvalContainer()
	
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


class ResourceContainers
	
	# <div> attribute names for source and eval nodes. 
	fileContainerAttr: "data-file"
	evalContainerAttr: "data-eval"
	
	constructor: (@resource) ->
		@url = @resource.url
	
	render: ->
		@fileNodes = (new Ace.EditorNode $(node), @resource for node in @files())
		@evalNodes = (new Ace.EvalNode $(node), @resource for node in @evals())
		$pz.codeNode ?= {}
		$pz.codeNode[file.editor.id] = file.editor for file in @files
		
	getEvalContainer: ->
		# Get eval container if there is one (and only one).
		return null unless @evalNodes?.length is 1
		@evalNodes[0].container
	
	files: -> $("div[#{@fileContainerAttr}='#{@url}']")
	
	evals: -> $("div[#{@evalContainerAttr}='#{@url}']")


class HtmlResource extends Resource
	
	update: (@content) ->
		$pz.renderHtml()


class ResourceInline extends Resource
	
	# Abstract class.
	# Subclass defines properties tag and mime.
	
	load: (callback) ->
		super =>
			@createElement()
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
			@Compiler = if @hasEval() then CoffeeCompilerEval else CoffeeCompiler
			@compiler = new @Compiler @url
			callback?()
			
	compile: ->
		$blab.evaluatingResource = this
		@compiler.compile @content
		@resultStr = @compiler.resultStr
		$.event.trigger("compiledCoffeeScript", {url: @url})
	
	update: (@content) -> @compile()


class JsonResource extends Resource


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
		if spec.url
			url = spec.url
			fileExt = Resource.getFileExt url
		else
			for p, v of spec
				# Currently handles only one property.
				url = v
				fileExt = p
		spec = {url: url, fileExt: fileExt}
		location = if url.indexOf("/") is -1 then "blab" else "ext"
		spec.location = location  # Needed for coffee compiling
		spec.gistSource = @gistFiles?[url]?.content ? null
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
	
	render: ->
		resource.render() for resource in @resources
	
	setGistResources: (@gistFiles) ->
		


#--- CoffeeScript compiler/evaluator ---#

class CoffeeCompiler
	
	constructor: (@url) ->
		@head = document.head
	
	compile: (@content) ->
		# ZZZ should this be done via eval, rather than append to head?
		console.log "Compile #{@url} - *NO* eval box"
		@head.removeChild @element[0] if @findScript()
		@element = $ "<script>",
			type: "text/javascript"
			"data-url": @url
		# ZZZ enhance with try/catch for errors
		js = CoffeeEvaluator.compile @content
		@element.text js
		@head.appendChild @element[0]
	
	findScript: ->
		$("script[data-url='#{@url}']").length


class CoffeeCompilerEval
	
	lf: "\n"
	
	constructor: (@url) ->
		@evaluator = new CoffeeEvaluator
	
	compile: (@content) ->
		# Eval node exists
		console.log "Compile #{@url} for eval box"
		recompile = true
		@resultArray = @evaluator.process @content, recompile
		@result = @evaluator.stringify @resultArray
		@resultStr = @result.join(@lf) + @plotLines()  # ZZZ should stringify produce this directly?
		
	plotLines: ->
		l = @evaluator.numPlotLines @resultArray
		return "" unless l>0
		lfs = ""
		lfs += @lf for i in [1..l]
		lfs
		
	findStr: (str) -> @evaluator.findStr @resultArray, str 


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
		js = CoffeeEvaluator.compile code unless js
		eval js
		js
	
	constructor: ->
		@js = null
	
	process: (code, recompile=true) -> #, stringify=true) ->
		stringify = true #ZZZ test
		compile = recompile or not(@evalLines and @js)
		if compile
			codeLines = code.split @lf
			# $blab.evaluator needs to be global so that CoffeeScript.eval can access it.
			$blab.evaluator = ((if @isComment(l) and stringify then l else "") for l in codeLines)
			@evalLines = ((if @noEval(l) then "" else "$blab.evaluator[#{n}] = ")+l for l, n in codeLines).join(@lf)
			js = null
		else
			js = @js
			
		try
			@js = CoffeeEvaluator.eval @evalLines, js  # Evaluated lines will be assigned to $blab.evaluator.
		catch error
			console.log "eval error", error
			
		return $blab.evaluator #unless stringify  # ZZZ perhaps break into 2 steps (separate calls): process then stringify?
		
	stringify: (resultArray) ->
		result = ((if e is "" then "" else (if e and e.length and e[0] is "#" then e else @objEval(e))) for e in resultArray)
		
	numPlotLines: (resultArray) ->
		# ZZZ generalize?
		n = null
		numLines = resultArray.length
		for b, idx in resultArray
			n = idx if (typeof b is "string") and b.indexOf("eval_plot") isnt -1
		d = if n then (n - numLines + 8) else 0
		if d and d>0 then d else 0
		
	findStr: (resultArray, str) ->
		p = null
		for e, idx in resultArray
			p = idx if (typeof e is "string") and e is str
		p
		
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
		try
			line = $inspect2(e, {depth: 2})
			line = line.replace(/(\r\n|\n|\r)/gm,"")
			return line
		catch error
			return ""

window.CoffeeEvaluator = CoffeeEvaluator

#--- Gist ---#

class Gist
	
	api: "https://api.github.com/gists"
	
	constructor: (@resources) ->
		@id = @getId()
		$(document).on "saveGist", => @save()
	
	load: (callback) ->
		unless @id
			@data = null
			callback?()
			return
		url = "#{@api}/#{@id}"
		$.get(url, (@data) =>
			console.log "get gist", @data
			@resources.setGistResources @data.files
			callback?()
		)
	
	save: ->
		
		@getAuth()
		
		console.log "Save to Gist (#{if @auth then @username else 'anonymous'})"
		
		resources = @resources.select (resource) ->
			resource.spec.location is "blab"
		files = {}
		files[resource.url] = {content: resource.content} for resource in resources
		
		ajaxDataObj =
			description: document.title
			public: false
			files: files
		ajaxData = JSON.stringify(ajaxDataObj)
			
		#@ajaxSpec =
			
			
		if @id and @username
			if @data.owner?.login is @username
				@patch ajaxData
			else
				console.log "Fork..."
				@fork((data) => 
					@id = data.id 
					@patch ajaxData, => @redirect()
				)
		else
			@create ajaxData
			
	create: (ajaxData) ->
		$.ajax
			type: "POST"
			url: @api
			data: ajaxData
			beforeSend: (xhr) => @authBeforeSend(xhr)
			success: (data) =>
				console.log "Created Gist", data
				@id = data.id
				@redirect()
			dataType: "json"
		
	patch: (ajaxData, callback) ->
		$.ajax
			type: "PATCH"
			url: "#{@api}/#{@id}"
			data: ajaxData
			beforeSend: (xhr) => @authBeforeSend(xhr)
			success: (data) ->
				console.log "Edited Gist", data
				callback?()
			dataType: "json"
		
	fork: (callback) ->
		$.ajax
			type: "POST"
			url: "#{@api}/#{@id}/forks"
			beforeSend: (xhr) => @authBeforeSend(xhr)
			success: (data) =>
				console.log "Forked Gist", data
				callback?(data)
			dataType: "json"
	
	redirect: ->
		blabUrl = "/?gist=#{@id}"
		window.location = blabUrl
		
	getId: ->
		query = location.search.slice(1)
		return null unless query
		h = query.split "&"
		p = h?[0].split "="
		gist = if p.length and p[0] is "gist" then p[1] else null
		
	getAuth: ->
		
		@username = $.cookie("gh_user")
		unless @username
			@username = window.prompt("GitHub username")
			return null unless @username
			document.cookie = "gh_user=#{@username}"
		@key = $.cookie("gh_key")
		unless @key
			@key = window.prompt("GitHub personal access token")
			return null unless @key
			document.cookie = "gh_key=#{@key}"
		
		make_base_auth = (user, password) ->
			tok = user + ':' + password
			hash = btoa(tok)
			"Basic " + hash
		
		@auth = make_base_auth @username, @key
		@authBeforeSend = (xhr) =>
			xhr.setRequestHeader('Authorization', @auth) if @auth

