#!/usr/bin/env python

import sys, os, re, getpass, datetime, time
import logging, wmproject.Logger
from optparse import OptionParser
from pysvn import Client, ClientError, Revision, opt_revision_kind
from wmproject.Cmd import ShellException

from wmproject.Project import Project

def shell(cmd,options):
    """Shell out and run a command"""
    
    log = logging.getLogger("shell")
    log.info(" > %s", cmd)
    if options.dryrun:
        return ["\n"]

    f = os.popen(cmd)

    lines = f.readlines()

    for line in lines:
        if line:
            log.info(" < %s", line)

    c = f.close()

    if c:
        log.info("returned %d", c)
    
    if c and options.abortOnError:
        raise ShellException(cmd,c)

    return lines


def ssh(cmd, options,user='build',host='build'):
    """Run a command over ssh"""

    # Construct ssh command and redirect stderr to stdout
    ssh = 'ssh %s@%s \"%s\"'%(user, host, cmd)

    return shell(ssh,options)

def getFileContents(log, filename):
    f = file(filename, 'r')
    contents = f.read()
    f.close()
    return contents.strip()

def main(argv=None):

    # Deal with arguments
    oparser = OptionParser(usage="%prog [--snap] [--release] [options] <project> <version>\nor: %prog --help")
    oparser.add_option("-b", "--branch",
                       dest="branch",
                       help="specify project branch (pre build_ctrl 1.11 only) "
                       "default: '%default'")
    oparser.add_option("-c","--complete",
                       dest="complete",
                       action="store_true",
                       help="when creating a snapshot, "
                       "use the latest-complete timestamp. "
                       "default: use latest timestamp")
    oparser.add_option("-r", "--release",
                       dest="release",
                       action="store_true",
                       help="create a release from a snapshot; if invoked with "
                       "-s or --snap, snapshot and release will be created at the same time. ")
    oparser.add_option("-s","--snap",
                       dest="snap",
                       action="store_true",
                       help="create a snapshot ")
    oparser.add_option("-p","--purpose",
                       dest="purpose",
                       help="document the purpose of this snapshot or release, "
                       "which will be written to a PURPOSE file.")
    oparser.add_option("-l","--no-best","--no-link",
                       dest="best",
                       action="store_false",
                       help="do not update best symlink to point to new snapshot or release. "
                       "default: best symlink is updated")
    oparser.add_option("-v","--verbose",
                       dest="verbose",
                       action="store_true",
                       help="log verbosely to stderr")
    oparser.add_option("-q","--quiet",
                       dest="verbose",
                       action="store_false",
                       help="don't spew status info (good for scripts)")
    oparser.add_option("-n","--dry-run","--no-act",
                       dest="dryrun",
                       action="store_true",
                       help="Don't actually do anything; "
                       "just print what would be done")
    oparser.add_option("-u", "--build",
                       dest="build",
                       help="specify which build to use (timestamp or symlink); "
                       "not compatible with --complete. "
                       "default: use the latest tinderbuild for a snapshot, or the best link for a release.")
    oparser.add_option("-a", "--alias",
                       dest="alias",
                       help="specify an alias (symlink) to use to refer to this snapshot or release "
                       "default: no alias")
    oparser.add_option("--relaxed",
                       dest="paranoid",
                       action="store_false",
                       help="turns off 'paranoid' checking. "
                       "default: paranoid checking is on")
    oparser.add_option("--paranoid",
                       dest="paranoid",
                       action="store_true",
                       help="turns on 'paranoid' checking. "
                       "default: paranoid checking is on")
    oparser.add_option("--unrelease",
                       dest="unrelease",
                       action="store_true",
                       help="Undoes a previous project release.")
    oparser.add_option("--notag",
                       dest="notag",
                       action="store_true",
                       help="skips tag creation (useful when re-creating a previous release.) "
                       "Only relevant when using --release. "
                       "default: notag is off, ie tag will be created")
    oparser.add_option("--override-patch",
                       dest="override_patch",
                       help="Use the specified patch number instead of number from project.xml. "
                       "Only relevant when using --release. "
                       "default: will use patch number from project.xml, if any.")
    oparser.add_option("-d", "--delete",
                       dest="always_delete",
                       action="store_true",
                       help="Automatically delete entire snap and tinderbuilds dirs when releasing. "
                       "Only relevant when using --release. "
                       "Not allowed with --no-best. "
                       "default: If not set, the script provides you with relevant info and prompts you in each case. ")
    oparser.add_option("-g", "--no-gradle-cache-delete",
                       dest="gradle_cache_delete",
                       action="store_false",
                       help="Do not delete the gradle cache on the build fileserver. "
                       "default: Delete the gradle cache when creating either a snapshot or release.")

    oparser.set_defaults(complete=False,
                         release=False,
                         unrelease=False,
                         purpose=None,
                         snap=False,
                         branch="main",
                         best=True,
                         verbose=True,
                         paranoid=True,
                         abortOnError=True,
                         dryrun=False,
                         build=None,
                         alias=None,
                         notag=False,
                         override_patch=None,
                         always_delete=False,
                         gradle_cache_delete=True)
                       
    if argv is None:
        argv = sys.argv
    (options, args) = oparser.parse_args(argv[1:])

    if len(args) < 2:
        oparser.error("<project> and <version> arguments are required")
    elif len(args) > 2:
        oparser.error("too many arguments")

    if not options.snap and not options.release and not options.unrelease:
        oparser.error("nothing to do; call with --snap and/or --release, or with --unrelease")

    if options.snap and options.unrelease:
        oparser.error("cannot use both --snap and --unrelease; use one or the other. (There is no current support for undoing a snapshot.)")

    if options.release and options.unrelease:
        oparser.error("cannot use both --release and --unrelease; use one or the other.")

    if options.unrelease and options.complete:
        oparser.error("the option --complete makes no sense in the context of --unrelease.")

    if options.unrelease and options.build:
        oparser.error("the option --build makes no sense in the context of --unrelease.")

    if options.complete and options.build :
        oparser.error("cannot use both --complete and --build; use one or the other.")

    if options.override_patch and not options.release:
        oparser.error("--override-patch makes no sense if --release is not defined.")

    if options.always_delete and not options.release:
        oparser.error("--delete makes no sense if --release is not defined.")

    if options.always_delete and not options.best:
        oparser.error("--delete not allowed with --no-best")

    if options.dryrun:
        options.verbose = True

    log = logging.getLogger('release-project')

    # configure logging
    if options.verbose:
        wmproject.Logger.setLevel(logging.INFO)
        log.info('verbose logging is configured')
        
    else:
        # default settings are fine
        wmproject.Logger.setLevel(logging.WARNING)
        pass
                            
    if options.dryrun:
        log.notice("Dry-run; not actually doing anything")

    testPythonSvn()

    (project,version) = args;

    # Don't run as 'build' or 'root'
    user = getpass.getuser()
    if user == 'build':
        oparser.error("do not run as 'build' user")
    elif user == 'root':
        oparser.error("do not run as 'root' user")

    # Determine build output directory
    if options.complete:
        timestamp = "latest-complete"
    elif options.build:
        # use specified build
        timestamp = options.build
    else:
        timestamp = "latest"

    if not options.build or options.build == "best":
        # a bit of pre-checking:
        if options.release and not options.snap:
            currentBest = os.path.realpath('/'.join(('/ext/build', project, version, 'best')))
            if currentBest and currentBest.find('tinderbuild') != -1:
                if options.paranoid:
                    oparser.error(
                        ('\n  Currently, the "best" link for version %s of %s points to a tinderbuild. Direct ' +
                        '\n  release of a tinderbuild is not recommended. Try retrying with "--snap --release" or "-sr". If ' +
                        '\n  releasing a tinderbuild is required, you may disable this check by rerunning with "--relaxed".') % (version, project))
                else:
                    log.info('!!! performing direct release of a tinderbuild.')
#            elif currentBest and currentBest.find('release') != -1:
            elif currentBest and currentBest.find('something') != -1:
                oparser.error(
                    '\n  Cannot find a snapshot to release - no snapshot specified, and best link points to an' +
                    '\n  existing release! Try one of:' +
                    '\n    1) re-running with "--snap --release" (or "-sr") to take a new snapshot and release it' +
                    '\n    2) specifying a snapshot directly with "--build"' +
                    '\n    3) manually fixing the "best" link by logging into the build server')

    try:
        if options.snap:
            snapshot(project,version,timestamp,options)
        if options.release:
            release(project,version,options.build,options)
        if options.unrelease:
            unrelease(project,version,options)
    except ShellException, e:
        return 1

# YYY/25523
def testPythonSvn():
    log = logging.getLogger("testPythonSvn")
    log.notice('If this script immediately exists with "Segmentation fault" or "Illegal instruction", see http://wiki/wiki/python-svn')
    c = Client()
    try:
        c.mkdir('svn+ssh://svn/wm/sandbox/bug25523', 'testing mkdir')
    except ClientError:
        # already exists
        pass

def getTimestamp(path):
    """Extract the trailing element of the supplied path, confirm that it is a timestamp"""

    # parse timestamp
    # our timestamps are of the form '2009.11.08-20.18'
    matchTimestamp = re.compile(r'.*\/([0-9]{4}[.][01][0-9][.][0-9]{2}-[0-9]{2}[.][0-9]{2})')
    m = matchTimestamp.match(path)
    if not m:
        raise Exception('Could not parse timestamp from link: ' + path)

    return m.group(1)

def findDepends(log, dir, options):
    log.info("Recording recursive build dependencies")
    cmd = "find-depends.pl --build %s > %s/depends.out" % (dir, dir)
    ssh(cmd,options)
    cmd = "find-depends-tree.pl --html --build %s > %s/depends-tree.html" % (dir, dir)
    ssh(cmd,options)

def getDate():
    return datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')

def writeSave(log, dir, message, options):
    log.info("Writing to SAVE file")
    date = getDate()
    cmd = "cd %s ; echo '%s' >> SAVE.$USER" % (dir, message + ' - ' + date)
    ssh(cmd,options)

def writePurpose(log, dir, options):
    log.info("Writing to PURPOSE file")
    
    escapedPurpose = options.purpose.replace("'", "\\'")

    if options.override_patch:
        escapedPurpose += '\n Note: this release overrides patch value from project.xml file with ' + options.override_patch
    cmd = "cd %s ; echo '%s' >> PURPOSE" % (dir, escapedPurpose)

    try: 
        ssh(cmd,options)
    except ShellException, e:
        log.warn('writing PURPOSE file resulted in an error; continuing, but you should manually create that file')
        
def updateBestLink(log, basePath, newValue, options):
    log.info("Updating best link")
    cmd = 'cd %s; ln -sfn %s best' % (basePath, newValue)
    ssh(cmd,options)

    if options.dryrun:
        # don't actually expect the best link to be updated in dry run mode, so no point in checking it.
        return

    # wait until best link is resolving correctly locally - this solves problems where
    # NFS lags behind for a few seconds.
    bestLinkPath = basePath + '/best'
    bestResolvePath = basePath + '/' + newValue
    tries = 0
    while tries < 6:
        resolvedPath = os.path.realpath(bestLinkPath)
        if resolvedPath == bestLinkPath:
            break
        tries += 1
        time.sleep(5)
    if tries == 3:
        raise Exception('waited 30 seconds, but still did not see best link %s resolving correctly to %s.' % (bestLinkPath, bestResolvePath))

def makeAlias(log, basePath, releaseName, alias, options):
    log.info("Creating alias")

    cmd = 'cd %(basePath)s; ln -sfn %(releaseName)s %(alias)s' % {'basePath' : basePath,
                                                                  'releaseName' : releaseName,
                                                                  'alias' : alias}
    ssh(cmd, options)

    if options.dryrun:
        # the alias isn't actually created in dry run mode, so no point in checking it.
        return

    # wait until new alias is resolving correctly locally - this solves problems where
    # NFS lags behind for a few seconds.
    releasePath = os.path.join(basePath, releaseName)
    aliasPath = os.path.join(basePath, alias)
    tries = 0
    while tries < 6:
        resolvedPath = os.path.realpath(aliasPath)
        if resolvedPath == releasePath:
            break
        tries += 1
        time.sleep(5)
    if tries == 3:
        raise Exception('waited 30 seconds, but still did not see new alias %s resolving correctly to %s.' % (aliasPath, releasePath))

def inputYorN(prompt, default):
    if default:
        prompt += ' [Y/n] '
    else:
        prompt += ' [y/N] '
    valid = False
    while not valid:
        ask = raw_input(prompt)
        if ask == 'Y' or ask == 'y':
            answer = True
            valid = True
        elif ask == 'N' or ask == 'n':
            answer = False
            valid = True
        elif ask == '':
            answer = default
            valid = True
    return answer

def inputNotEmpty(prompt):
    answer = ''
    while not answer:
        answer = raw_input(prompt)
    return answer    

def deleteDir(log, project, version, path, dirType, options):
    if (os.path.isdir(path)):

        if (options.always_delete):
            delete = True
        else:
            dryrunSave = options.dryrun
            abortOnErrorSave = options.abortOnError
            options.dryrun = False
            options.abortOnError = False
            
            log.info('Contents of ' + dirType + ' dir follows')
            cmd = 'ls -lF ' + path
            shell(cmd, options)
            
            log.info('SAVE files in ' + dirType + ' dir are as follows')
            cmd = 'ls -lF ' + path + '/*/[Ss][Aa][Vv][Ee]*'
            shell(cmd, options)
            
            options.dryrun=dryrunSave
            options.abortOnError=abortOnErrorSave

            if options.best:
                default = True
            else:
                # I suppose we could be a little smarter here and
                # actually try to resolve the best link and take
                # intelligent action based on that
                default = False
                log.notice('YOU MAY NOT WANT TO DO THIS BECAUSE YOU ARE NOT UPDATING THE BEST LINK')
            delete = inputYorN('Delete entire ' + dirType + ' dir?', default)

        if delete:
            if dirType == 'tinderbuilds':
                latest = path + '/../latest'
                tlatest = path + '/latest'
                if os.path.samefile(latest, tlatest):
                    log.info('Deleting latest symlink')
                    ssh('rm -f ' + latest, options)
            log.info('Deleting ' + dirType + ' dir')
            ssh('rm -f -r ' + path, options)
        else:
            log.info('NOT deleting ' + dirType + ' dir');
            reason = inputNotEmpty('Describe the reason for keeping the ' + dirType + ' dir: ')
            date = getDate()
            msg = date + ' ' + dirType + ' dir not deleted during release of ' + project + ' ' + version + ' by $USER: ' + reason
            escapedMsg = msg.replace("'", "\\'")
            cmd = "cd %s ; echo '%s' >> NOTDELETED" % (path, escapedMsg)
            try: 
                ssh(cmd,options)
            except ShellException, e:
                log.warn('writing NOTDELETED file for ' + dirType + ' dir resulted in an error; continuing')

    else:
        log.info('There is no ' + dirType + ' dir')

# YYY/TOOL-220
def deleteGradleCache(log, basePath, project, version, options):
    if (options.gradle_cache_delete):
        realPathArray = str.split(os.path.realpath(basePath),
                                  '/')
        if realPathArray[1] == 'ext':
            host = realPathArray[2]
            log.info('Fileserver host for project %s version %s is %s', project, version, host) 
            gradleCacheDir = "/var/tmp/build/gradle/%s/%s" % (project, version)
            log.info("Removing gradle cache dir %s from host %s if it exists" % (gradleCacheDir, host))
            cmd = "if [[ -d %s ]]; then rm -f -r %s && echo \"Removed %s\"; else echo \"Dir does not exist: %s\"; fi" % (gradleCacheDir, gradleCacheDir, gradleCacheDir, gradleCacheDir)
            ssh(cmd, options, host=host)
        else:
            log.warn('Can not determine fileserver for project %s version %s, will not delete gradle cache even if applicable', project, version)
    else:
        log.info("Not deleting gradle cache because option was specified to override default behavior")

def snapshot(project,version,timestamp,options):
    """Take a snapshot"""
    
    log = logging.getLogger("snapshot")
    log.info('Beginning snapshot')
    
    # branch is legacy
    branch = version

    # Construct input path
    basePath = '/ext/build/%s/%s' % (project, version)
    path = basePath + '/tinderbuilds/' + timestamp
    legacy_path = '/ext/build/' + project + '/' + options.branch + '/tinderbuilds/' + timestamp

    if os.path.exists(path):
        # ok
        pass
    elif os.path.exists(legacy_path):
        # use legacy path
        basePath = '/ext/build/' + project + '/' + options.branch
        path = legacy_path
        branch = options.branch
    else:
        raise Exception("Could not find build path for project '%s', version '%s' (%s), timestamp '%s'" % (project, version, branch, timestamp))

    # get timestamp from path, and verify that it contains a timestamp
    resolvedPath = os.path.realpath(path)
    timestamp = getTimestamp(resolvedPath)

    replaceSuffix = re.compile(r'tinderbuilds/.*')

    snapType = 'snap'
    snapDir=replaceSuffix.sub(snapType,path)

    log.info("Creating snapshot")
    log.info(" from: %s", path)
    log.info(" to:   %s", snapDir)

    # Save (hardlink)
    log.info("Saving snapshot:")
    cmd = ' '.join(('save-snapshot', project, timestamp, branch, snapType))
    ret = ssh(cmd,options)
    if options.dryrun:
        ret = [os.path.realpath(path).replace("tinderbuilds","snap") + "\n"]
    snapPath = ret[0].replace('\n','')

    # recursively find dependencies and record
    findDepends(log, snapPath, options)

    # SAVE file
    msg = "%s %s release-candidate" % (project, version)
    writeSave(log, snapPath, msg, options)

    if (options.purpose):
        writePurpose(log, snapPath, options)

    if (options.best):
        updateBestLink(log, basePath, snapType + '/' + timestamp, options)

    if (options.alias):
        makeAlias(log, os.path.dirname(snapPath), os.path.basename(snapPath), options.alias, options)

    deleteGradleCache(log, basePath, project, version, options)

def release(project,version,build,options):
    """Release a project/version"""

    log = logging.getLogger("release")
    log.info('Beginning release')

    client = Client()

    # Check to make sure version will be legal as a tag
    reg =re.compile('[-a-zA-Z0-9_.]+');
    for x in range(len(version)):
        if  reg.match(version[x]) == None:
            raise Exception("The version specified has characters that are not legal for setting a tag.")

    basePath = '/ext/build/' + project + '/' + version

    # resolve path to snapshot

    if (build == 'best'):
       log.info("Resolving best link:")
    else:
       log.info("Resolving link to snapshot '%s':" % (build))
    
    if build:
        # try snapshot first
        snapPath = basePath  + '/snap/' + build
        snapSource = 'SNAP'
        if not os.path.exists(snapPath):
            # try tinderbuilds
            snapPath = basePath + '/tinderbuilds/' + build
            snapSource = 'TINDERBUILD'
        if not os.path.exists(snapPath):
            # try base
            snapPath = basePath + '/' + build
            snapSource = 'BASE'

        if not os.path.exists(snapPath):
            raise Exception("Could not find specified build %s for %s %s" % (build,project,version))
    else:
        snapPath = basePath + '/best'
        snapSource = 'BEST'
        if not os.path.exists(snapPath):
            raise Exception('Could not find best link at %s - either create a best link or retry with "--build".' % (snapPath))


    if options.paranoid and snapSource == 'TINDERBUILD':
        raise Exception('Specified build found at %s. Direct release of tinderbuild is not recommended. Rerun with "-sv" to snapshot your build first, or use "--relaxed" to disable this check.' % snapPath)

    # get canonical path
    path = os.path.realpath(snapPath)
    # parse timestamp
    timestamp = getTimestamp(path)

    # determine tag
    project_xml = path + '/src/project.xml'
    if not os.path.exists(project_xml):
        project_xml = path + '/src/' + project + '_project/project.xml'
    if not os.path.exists(project_xml):
        raise Exception('Could not find project.xml at: ' + project_xml)

    proj = Project(project_xml)

    tag = version
    patch = None
    if proj.patch:
        patch = proj.patch

    if options.override_patch:
        patch = options.override_patch

    if patch: 
        # It would be reasonable / intuitive for a user to include a leading p in override_patch.
        # Remove any leading ps or spaces to normalize expectations.
        patch = patch.strip('p \t')

        tag += 'p' + patch

    if options.override_patch:
        log.warn('using tag %s, including override patch number instead of value from project.xml (%s)' % (tag, proj.patch))

    # Determine if this is SVN or git
    scmgit=False
    scmsvn=False
    if os.path.exists(path + '/git-checkout.log'):
        scmgit=True
    else:
        if os.path.exists(path + '/svn-checkout.log'):
            scmsvn=True
	else:
            raise Exception('Could not determine SVN or GIT')

    # determine checkout revision and path
    if scmsvn:
        info = client.info(path + "/src")
        rev = info.revision
        svnpath = info.url.replace("svn://","svn+ssh://")

        if options.paranoid:
            if svnpath.find(project) == -1:
                raise Exception('The project you''re trying to release doesn''t contain its project name %s in its SVN path %s. Something is horribly wrong. (Use "--relaxed" to disable this check.)'
                                % (project, svnPath))
        
    # Determine tag path
    tagDir = 'svn+ssh://svn/wm/project/' + project + '/tags'
    tagPath =  tagDir + '/' + tag
    # For git, make sure the repo is writable by the current user
    if scmgit:
       cmd = 'ssh git@git'
       results=shell(cmd,options)
       repo_match=False
       repo_writable=False
       for x in range(len(results)):
          if results[x].lstrip('@_RW \t\r\n').rstrip('\r\n') == project:
             repo_match=True
             if results[x][9]=='W':
                 repo_writable=True
             else:
                 raise Exception('You dont have right to make changes to the repo for this project, therefore you cannot set the tag.')


    # check that tag doesn't already exist
    if not options.notag:
        if scmsvn:
            try:
                client.ls(tagPath)

                # tag exists already! Oops!
                raise Exception(
                        'Tag path %s already exists! Halting. (You can use --notag to disable tag creation and this check.)'
                        % (tagPath))
            except ClientError:
                # this is expected, as we haven't created it yet.
                pass

            
    log.info("Releasing:")
    log.info(" build: %s", path)
    if scmsvn:
       log.info(" svn:   -r %d %s", rev.number, svnpath)
    if scmgit:
       log.info(" git")
    log.info(" tag:   %s", tag)

    # Make release dirs
    log.info("Ensuring that release directories exist")
    releasesDir = basePath  + '/releases'
    allReleasesDir = '/ext/build/' + project + '/releases'

    ssh('mkdir -p ' + releasesDir,options)
    ssh('mkdir -p ' + allReleasesDir,options)

    # Copy to releases
    log.info("Moving snap to releases")

    cmd = 'test -d ' + path + ' && mv ' + path + ' ' + releasesDir
    ssh(cmd,options)

    # Create soft links
    log.info("Create soft links")

    cmd = 'cd ' + releasesDir + '; test -e ' + tag + ' || ln -s ' + timestamp + ' ' + tag
    ssh(cmd,options)
    cmd = 'cd ' + allReleasesDir + '; test -e ' + tag + ' || ln -s ../' + version + '/releases/' + tag + ' ' + tag
    ssh(cmd,options)

    # recursively find dependencies and record
    # this will overwrite any previous instances (e.g. from a snapshot)
    findDepends(log, releasesDir + "/" + timestamp, options)

    # Edit save file
    log.info("Appending to SAVE file")

    msg = '%s %s RELEASE' % (project, version)
    writeSave(log, releasesDir + '/' + tag, msg, options)

    # Create project tags directory
    if scmsvn:
       try:
           client.ls(tagDir)
           log.info("Project tags directory already exists")
       except ClientError:
           # does not exist, so create it
           log.info("Creating project tags directory")
           if not options.dryrun:
               client.mkdir(tagDir,'release-project: make tag directory for ' + project)

       if options.notag:
           log.notice('skippping tag creation, as --notag is set')

           # may want to write tag file, if svn path has a tag in it already.
           if svnpath.find('/tags/') != -1:
               log.notice('src svnpath is a tag already, writing that to TAG path')
               cmd = 'cd ' + releasesDir + '/' + tag + '; echo ' + svnpath + ' >> TAG'
               ssh(cmd,options)
       else:
           # Make tag
           log.info("Tagging project")
           log.info(" > svn copy -r%d %s %s", rev.number, svnpath, tagPath)
           message = 'release-project: saving release tag'

           def get_log_message(): return True, message

           client.callback_get_log_message = get_log_message
           if not options.dryrun:
               client.copy(svnpath, tagPath, rev)
           client.callback_get_log_message = None

        # Log to TAG file
           log.info("Creating TAG file")
    
           cmd = 'cd ' + releasesDir + '/' + tag + '; echo ' + tagPath + ' >> TAG'
           ssh(cmd,options)
        
        #Create tag for git
    if scmgit:
        cmd = 'cd ' + releasesDir + '/' + tag + '/src && git show --format=oneline --summary | cut -d \' \' -f 1'
        githash=shell(cmd,options)
        cmd = 'ssh git@git addtag ' + project + ' ' + version + ' ' + githash[0]
        try:
           shell(cmd,options)
        except ShellException, e:
           raise Exception('Something went wrong with the addtag command. Check the log to see what the error was')
        cmd = 'cd ' + releasesDir + '/' + tag + '/src && git fetch'
        ssh (cmd,options)


    if (options.purpose):
        writePurpose(log, releasesDir + '/' + tag, options)

    if options.best:
        # Update best link
        updateBestLink(log, basePath, 'releases/' + timestamp, options)

    if (options.alias):
        makeAlias(log, releasesDir, timestamp, options.alias, options)

    snapDir = basePath + '/snap'
    tinderbuildsDir = basePath + '/tinderbuilds'
    # use tag instead of version so that we get the patch number
    deleteDir(log, project, tag, snapDir, 'snap', options)
    deleteDir(log, project, tag, tinderbuildsDir, 'tinderbuilds', options)

    deleteGradleCache(log, basePath, project, version, options)

def unrelease(project,version,options):
    """Undoes the project release for the specified project/version"""

    log = logging.getLogger("unrelease")

    client = Client()

    # calculate version with and without patch number
    matchPatch = re.compile(r'([1-9][0-9.]+)p([1-9][0-9.]*)')
    m = matchPatch.match(version)
    if m:
        baseVersion = m.group(1)
        fullVersion = version
        patch = m.group(2)
    else:
        baseVersion = version
        fullVersion = version
        patch = None

    basePath = '/ext/build/%s/%s' % (project, baseVersion)
    releaseLinkPath = basePath + '/releases/' + fullVersion
    if not os.path.exists(releaseLinkPath):
        raise Exception('Could not find link to release %s for %s at %s' % (version,project,releaseLinkPath))

    # get canonical path
    releasePath = os.path.realpath(releaseLinkPath)

    # sanity check
    if releasePath.find('releases') == -1:
        raise Exception('Symlink %s in releases directory points to non-release path %s - something is wrong. You''ll have to fix that manually.' % (releaseLinkPath, releasePath))
    # Determine if this is SVN or git
    scmgit=False
    scmsvn=False
    if os.path.exists(releasePath + '/git-checkout.log'):
        scmgit=True
    else:
        if os.path.exists(releasePath + '/svn-checkout.log'):
            scmsvn=True
	else:
            raise Exception('Could not determine SVN or GIT')


    # get timestamp name
    timestamp = getTimestamp(releasePath)

    snapPath = basePath + '/snap/' + timestamp

    # remove existing best link, decide whether to fix it at the end
    # logic here is:
    #  - if we are told not to modify best, don't.
    #  - otherwise, if best link doesn't exists
    #     or if it exists and points to this build
    #     or if it points nowhere
    #    then fix it to point to the snapshot after we've moved it.
    updateBest = False
    bestLinkPath = basePath + '/best';
    if options.best:
        if (not os.path.exists(bestLinkPath)
                or os.path.realpath(bestLinkPath) == releasePath
                or (not os.path.exists(os.path.realpath(bestLinkPath)))):
            log.info('removing old best link')
            ssh('rm -f ' + bestLinkPath, options)
            updateBest = True

    log.info('Removing release links')
    cmd = 'rm /ext/build/%s/%s/releases/%s' % (project, baseVersion, fullVersion)
    ssh(cmd, options)
    cmd = 'rm /ext/build/%s/releases/%s' % (project, fullVersion)
    ssh(cmd, options)

    # get tag path
    if scmsvn:
       tagUrl = getFileContents(log, releasePath + '/TAG')
       log.info("tag URL is '%s'" % (tagUrl))

    # delete tag
       log.info('deleting SVN tag')
       msg =  'Removing tag from reversed release of project %s, version %s' % (project, version)
       escapedMessage = msg.replace("'", "\\'")
       shell('svn rm %s -m \'%s\'' % (tagUrl, escapedMessage), options)

    # write UNTAG file, remove TAG file
       log.info('removing TAG file, writing to UNTAG file')
       cmd = "rm %s/TAG ; echo '%s' >> %s/UNTAG" % (releasePath,tagUrl,releasePath)
       ssh(cmd, options)
    if scmgit:
       cmd = 'ssh git@git deltag ' + project + ' ' + version
       try:
          shell(cmd,options)
       except ShellException, e:
          raise Exception('Something went wrong with the deltag command. Check the log to see what the error was')
#       cmd = 'cd ' +  basePath + ' && git tag -d ' + version
#       ssh(cmd,options)




    # write more to SAVE file about unrelease
    msg = '%s %s UNRELEASE' % (project, version)
    writeSave(log, releasePath, msg, options)

    # move release back to snap dir
    log.info('moving released snapshot back to snap directory')
    cmd = 'mkdir -p %s' % (snapPath)
    ssh(cmd, options)
    cmd = 'mv %s %s' % (releasePath, snapPath)
    ssh(cmd, options)

    # possibly create updated best link
    if updateBest:
        updateBestLink(log, basePath, 'snap/' + timestamp, options)

if __name__ == "__main__":
   sys.exit(main())

##
## Local Variables:
##   mode: python
##   py-indent-offset: 4
##   tab-width: 4
##   indent-tabs-mode: nil
## End:
##
## vim: softtabstop=4 tabstop=4 expandtab shiftwidth=4
##
