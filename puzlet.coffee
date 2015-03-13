###
Puzlet Bootstrap
###

localOrg = "../../puzlet"
puzletOrg = "http://puzlet.org"
loaderPath = "/puzlet/js/loader.js"  # repo/folder/file

window.console = {} unless window.console?
window.console.log = (->) unless window.console.log?

console.log "Puzlet bootstrap"

# Host
a = document.createElement "a"
a.href = window.location.href
host = a.hostname
isLocalHost = host is "localhost"

# Loader URLs
localLoaderUrl = localOrg + loaderPath
puzletLoaderUrl = puzletOrg + loaderPath
loaderUrl = if isLocalHost then localLoaderUrl else puzletLoaderUrl

# Script loader
loadScript = (url, onError) ->
	script = document.createElement "script"
	script.setAttribute "type", "text/javascript"
	script.setAttribute "src", url
	script.onerror = onError
	document.head.appendChild script

# Loading-error function
loadFromPuzlet = ->
	console.log "No loader.js found on localserver.  Loading #{puzletLoaderUrl}."
	loadScript puzletLoaderUrl, ->  # puzlet.org
onError = if isLocalHost then loadFromPuzlet else (->)

# Load loader.js
console.log "Attempting to load from localhost." if isLocalHost
console.log "Loading #{loaderUrl}."
loadScript loaderUrl, onError
