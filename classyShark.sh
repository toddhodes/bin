
case "$1" in
"") echo "Usage: $0 <apk>"; exit 0;;
"-h"|"--help") 
echo "Open APK java -jar ClassyShark.jar -open <YOUR_APK.apk>";
echo "Export all generated data to a text file java -jar ClassyShark.jar -dump <BINARY_FILE>";
echo "Export generated file from a specific class to a text file java -jar ClassyShark.jar -dump <BINARY_FILE> <FULLY_QUALIFIED_CLASS_NAME>";
echo "Open ClassyShark and display a specific class in the GUI java -jar ClassyShark.jar -open <BINARY_FILE> <FULLY_QUALIFIED_CLASS_NAME>";
echo "Inspect APK java -jar ClassyShark.jar -inspect <YOUR_APK.apk>";
echo "Dump all strings (combined classes.dex string tables) from your APK java -jar ClassyShark.jar -stringdump <YOUR_APK.apk>";
exit 0 ;;
esac

java -jar ~/bin/ClassyShark.jar -open $1

