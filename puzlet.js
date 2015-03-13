// Generated by CoffeeScript 1.3.3

/*
Puzlet Bootstrap
*/


(function() {
  var a, hasPath, host, hostParts, isLocalHost, isPuzlet, path, pathParts, search, url;

  console.log("Puzlet bootstrap");

  if (window.console == null) {
    window.console = {};
  }

  if (window.console.log == null) {
    window.console.log = (function() {});
  }

  url = window.location.href;

  a = document.createElement("a");

  a.href = url;

  host = a.hostname;

  path = a.pathname;

  search = a.search;

  hostParts = host.split(".");

  pathParts = path ? path.split("/") : [];

  hasPath = pathParts.length;

  isLocalHost = host === "localhost";

  isPuzlet = host === "puzlet.org";

  console.log("host/path/search", host, path, search);

}).call(this);