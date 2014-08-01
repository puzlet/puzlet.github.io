console.log "window.location", window.location

$.getJSON("/cs-intro/test.json", (data) ->
  $("#app_container").append data.test
)