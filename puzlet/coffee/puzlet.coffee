console.log "window.location", window.location

getBlab = ->
	query = location.search.slice(1)
	return null unless query
	h = query.split "&"
	p = h?[0].split "="
	blab = if p.length and p[0] is "blab" then p[1] else null
	return null unless blab
	$.getJSON("/#{blab}/test.json", (data) ->
		$("#app_container").append data.test
	)
	
getBlab()