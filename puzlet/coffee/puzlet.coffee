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
		htmlNode()
		$("#codeout_html").append Wiky.toHtml(data)
		new MathJaxProcessor
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


$(document).ready ->
	Array.prototype.dot = (y) -> numeric.dot(+this, y)  # ZZZ temp
	getBlab()

