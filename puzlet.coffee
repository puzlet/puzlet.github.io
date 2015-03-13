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

# Loader
localLoaderUrl = localOrg + loaderPath
puzletLoaderUrl = puzletOrg + loaderPath
loaderUrl = if isLocalHost then localLoaderUrl else puzletLoaderUrl

console.log "Attempting to load #{loaderUrl} (localhost)."
script = document.createElement "script"
script.setAttribute "type", "text/javascript"
script.setAttribute "src", loaderUrl
script.onerror = ->
	console.log "No loader.js found on localserver.  Loading #{puzletLoaderUrl}."
	script.setAttribute "src", puzletLoaderUrl  # puzlet.org
	document.head.appendChild script
document.head.appendChild script

# Caching
#t = Date.now()
