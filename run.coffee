#!/usr/bin/env coffee

{normalize, resolve, join} = require "path"
fs = require "fs"
{join} = require "path"
gulp = require "gulp"
gutil = require "gulp-util"
prettyTime = require "pretty-hrtime"
program = require "commander"

isValidMoonbasePath = (path) ->
	for folder in ["pages", "templates", "assets"]
		if not fs.existsSync(join(path, folder))
			return false
		if not fs.lstatSync(join(path, folder)).isDirectory()
			return false
	return true

task = "watch"
path = process.cwd()
args = []

program
	.version("0.0.1")
	.arguments("moonbase [path] [task] [args...]")
	.action (cmdtask, cmdpath, args) ->
		task = cmdtask or task
		path = cmdpath or path
		args = args


program.parse(process.argv)

path = resolve(normalize(path))

console.log fs.readFileSync(join(__dirname, "banner.txt"), "utf8")

gutil.log "Running #{task} for #{path}"

if not isValidMoonbasePath(path)
	gutil.log gutil.colors.red("Error: this is not a moonbase project path:")
	gutil.log gutil.colors.red(path)
	process.exit(1)

process.chdir(path)
gulpfile = require "./gulpfile"

gulp.on "task_stop", (e) ->
	gutil.log "#{e.task} #{gutil.colors.grey("in")} #{prettyTime(e.hrDuration)}"


gulp.start(task)
