This file documents enterprise standards that are best practice on coding projects. 

# Bash/Shell Scripts

## Self documenting / help text
Bash scripts should have documentation embedded in them. The term "bash script" is analagous to any shell script such as ZSH and DASH. 

For example:

```sh
#!/bin/sh

## Script
## - A script that does a thing
## 
## $1 - the first arg that is for a thing
## $2 - the second arg that does a thing

if [ "$1" == "--help" ];then
    cat $0 | grep "##" | tr -d "#"
    exit 0
fi

# A regular comment, that isn't in the help
echo "Hello World"
```
  
As we can see there are several "features" in the hello world above:
- Comments with ## are included in the help text
- The script is able to read its own contents and print the help text
- Regular comments with a single `#` aren't included in the help text
- A basic description of what the script does is in the help text
- A basic description of what the args do is in the help text; if the script uses positional args

## Dependency aware
shell scripts should be aware when they are using non-standard programs & check that they are installed on the host machine. For example:

```sh
#!/bin/sh

hasProgram () {
    command -v "$1" >/dev/null 2>&1
    HAS_PROGRAM="$?"

    if [ $HAS_PROGRAM -ne 0 ]; then
        echo "Error: $1 is not installed."
        exit 1
    fi
}

hasProgram "python3"
hasProgram "jq"
hasProgram "this_program_is_not_installed"
```

This has a couple of features:
- hasProgram is extracted to a function; many unix like environments have a program like `require` but this isn't present on many machines so it's often necessary to include a function
- Commands like jq are useful but may not be installed on everyones machine; if the script tried to use jq when it's not installed the behavior may be undesired
- Commands that aren't installed like `this_program_is_not_installed` used as a reference example will cause the script to exit and return an error

## Logging
Scripts should implement logging. Logging may go to a remote HEC like splunk, a local HEC like fluent bit, or be unconfigured. 

An example logging payload could look like:
```json
{"event": "Hello, world!", "level": "INFO", "status: "success", "sourcetype": "script", "time": "28/Sep/2016:09:05:26.917 -0700"}
```

The same log written to STD_OUT could look like:
```txt
[INFO] [status=success] [28/Sep/2016:09:05:26.917 -0700] -- Hello, world!
```

The timezone should be the timezone of the machine it's running on. 
Also for items that fail the status should be failure. 

Remote logging should be configured via the ENV var `HEC_REMOTE_LOG`. The use of this
env var should be documented in the scripts help text. If this var is unset or empty then it should be assumed that remote logging is disabled. Logs should always be logged to STD_OUT even when remote logging is enabled or not. 