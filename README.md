# docker-shell

A set of usefull functions for writing interactive [docker](https://www.docker.com/) `build` and `run` scripts.
Dependencies are: [`rlwrap`](http://utopia.knoware.nl/~hlub/uck/rlwrap/#rlwrap), `bash`, `sudo`, `curl`, and `docker` (surprise! :)

Functions take named parameters via environment variables e.g. `FOO="test" my_func`, 
most require a special variable named `VAR` which contains name of environment 
variable that will contain function result:

```bash
VAR=TEST my_foo
# Now $TEST contains result of running my_foo (most likely some string)
echo $TEST # outputs result of running my_foo
```

`shared-functions.sh` is not that long, go ahead and read it. Each function contains 
a comment with possible argument variables. Some of them are bypassed as is to an 
inner function invokation so it's not that obvious.

Note, that after running set of commands with the right name passed to `VAR` there is 
no need pass that vars to later commands explicitly:
```bash
VAR=TEST1 my_foo
VAR=TEST2 my_bar

# $TEST1 and $TEST2 are available here
# no need to run
TEST1="$TEST1" TEST2="$TEST2" foo_bar
# just call
foo_bar
```
