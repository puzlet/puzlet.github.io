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


getBlab = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null
	return null unless blab
	
	css = $ "<link>",
		rel: "stylesheet"
		type: "text/css"
		href: "/#{blab}/main.css"
	$(document.head).append css
	
	# ZZZ Hard coded
	#d = $ "<script>",
	#	src: "http://puzlet.com/puzlet/php/source.php?pageId=b00bj&file=d3.min.js"  # Another CDN?
	#$(document.head).append d
	
	$.get("/#{blab}/main.html", (data) ->
		$("#codeout_html").append Wiky.toHtml(data)
		new MathJaxProcessor
		
		js = $ "<script>",
			src: "/#{blab}/main.js"
		console.log "js", js
		$(document.head).append js
	)
	
htmlNode = ->
	html = """
	<div id="code_nodes" data-module-id="b00cv">
	<div class="code_node_container" id="code_node_container_html" data-node-id="html" data-filename="main.html">
		<div class="code_node_output_container" id="output_html">
			<div class="code_node_html_output" id="codeout_html"></div>
		</div>
	</div>
	</div>
	"""
	$("#app_container").append html
	
gistTest = ->
	# https://api.github.com/users/'+username
	# /users/:username/gists
	
	#url = "https://api.github.com/users/mvclark/gists"
	url = "https://api.github.com/gists/d766b1f32ab6c2258da2"
	
	$.get(url, (data) ->
		console.log "gist", data
	)
	
	url2 = "https://gist.githubusercontent.com/mvclark/2c1f80c07c67466170ee/raw/c4c27a1698de5e6b812372abfdea2d7e28e24169/test.js"
	$.get(url2, (data) ->
		console.log "gist data", data
	)
	
	d = {
		description: "the description for this gist"
		public: true
		files: {
			"file1.txt": {
				content: "String file contents"
			}
		}
	}
	return # ZZZZZZZ
	$.ajax({
		type: "POST"
		url: "https://api.github.com/gists"
		data: JSON.stringify(d)
		success: (data) -> console.log "create gist", data
		dataType: "json"
	})

$(document).ready ->
	$("#ribbon").fadeTo 1000, 0.2
	#new ArrayMath
	Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	#a = [1..100]
	#console.log "a", a, a.dot
	htmlNode()
	getBlab()
	gistTest()


