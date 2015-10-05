exports.config =
	
	settings:
		minifyCSS: false
		minifyJS: true

	before: -> console.log "before"
	after: -> console.log "after"
	page: (page) ->
		domain: "domain.com"
		posts: []
