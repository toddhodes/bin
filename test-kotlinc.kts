#!/usr/bin/env kotlinc -script

import java.io.File

if (args.size > 0) {
   val folders: Array<out File> = File(args[0]).listFiles { file -> file.isDirectory }!!

   folders.forEach { folder -> println(folder) }
}
