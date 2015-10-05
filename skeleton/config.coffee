exports.config =
	before: -> # Before every build 
	after: -> # After every build
	page: (path, file) ->
		domain: "domain.com"
		path: path


