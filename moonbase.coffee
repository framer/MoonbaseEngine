#!/usr/bin/env coffee

{normalize, resolve} = require "path"
gulp = require "gulp"
program = require "commander"

task = "watch"
path = process.cwd()

program
	.version('0.0.1')
	.arguments('moonbase [task] [path]')
	.action (cmdtask, cmdpath) ->
		task = cmdtask or task
		path = cmdpath or path

program.parse(process.argv)

path = resolve(normalize(path))

console.log "Running #{task} for #{path}"

process.chdir(path)
gulpfile = require "./gulpfile"

gulp.start(task)