# Args to compile_and_run are:
#	extra compile flags
#	extra run flags
#	expected process return value, if not zero

# Only compile with optimisation
def f( name, opts ):
  opts.only_ways = ['optasm']

setTestOpts(f)

test('T13588', [ grep_errmsg('case') ] , compile, ['-dverbose-stg2stg -fno-worker-wrapper'])
test('T19717', normal, compile, ['-ddump-stg-final -dsuppress-uniques -dno-typeable-binds'])
test('inferTags002', [ only_ways(['optasm']), grep_errmsg('(call stg\_ap\_0)', [1])], compile, ['-ddump-cmm -dsuppress-uniques -dno-typeable-binds -O'])

test('T22212', normal, compile, ['-O'])
