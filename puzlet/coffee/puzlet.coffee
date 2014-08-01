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
	
	$.get("/#{blab}/main.html", (data) ->
		$("#codeout_html").append Wiky.toHtml(data)
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

htmlNode()
getBlab()


