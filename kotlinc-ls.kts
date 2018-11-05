#!/usr/bin/env kotlinc -script

import java.io.File

var dir = "."
if (args.size > 0) {
   dir = args[0]
}

val folders: Array<out File> = File(dir).listFiles { file -> file.isDirectory }!!

folders.forEach { folder -> println(folder) }
