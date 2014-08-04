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