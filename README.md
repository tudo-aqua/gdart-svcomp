# The GDart tool

GDart is a tool ensemble for the dynamic symbolic execution of modern Java.
GDart consists of three components:
- DSE a generic dynamic symbolic execution (https://github.com/tudo-aqua/dse)
- SPouT: Symbolic Path Recording During Testing (https://github.com/tudo-aqua/spout)
- JConstraints: A meta solving library for SMT problems (https://github.com/tudo-aqua/jconstraints)

To verify a a SV-COMP benchmark example, just call the ./run-gdart.sh script:
`./run-gdart.sh property path_to_java_common path_to_folder_containint_Main_class`

GDart runs on MacOS and Ubuntu (22.04). Windows is currently not supported.

## Building

```bash
git clone --recurse-submodules https://github.com/tudo-aqua/gdart-svcomp.git
cd gdart-svcomp
./compile-all.sh
```

Requirements: git, python3, a C toolchain (Xcode command line tools / `build-essential`, zlib), cmake,
Maven >= 3.9, JDK 21 or later (found automatically or set `JDK21_HOME`; jConstraints is compiled for Java 21), network access (GitHub, JitPack, Maven Central),
about 15 GB of disk and 16 GB of RAM.

`compile-all.sh` (restartable, logs in `build-logs/`):

1. clones mx 7.54.5, registers `labsjdk-gdart` (labsjdk 25 with JVMCI, `update_common.py`) and downloads it,
2. installs jConstraints into `~/.m2` (DSE depends on it) and builds the verifier stub,
3. builds SPouT, the native standalone of Espresso with the concolic analyses
   (`SPouT/espresso/mxbuild/<platform>/ESPRESSO_NATIVE_STANDALONE`, 20-60 min),
4. copies `java.base.jmod` of the labsjdk into DSE (OPAL analyzes the JDK classes that SPouT runs) and builds DSE,
5. links the JDK to `jdk` (DSE and `javac` run on it) and writes `version.txt`.

## Layout of the tool directory

```
run-gdart.sh, executor.sh, version.txt
SPouT/espresso/mxbuild/<platform>/ESPRESSO_NATIVE_STANDALONE   (executor.sh: bin/java runs the program)
dse/target/dse-0.0.1-SNAPSHOT-jar-with-dependencies.jar
verifier-stub/target/verifier-stub-1.0.jar
jdk                                                            (JDK 21: DSE and javac)
```

For the SV-COMP archive, copy these files (`cp -rL` for `jdk`); the sources are not needed.

## Configuration

`run-gdart.sh` runs DSE with Z3, BFS, 10 s per solver query, incremental constructor summaries and a DSE timeout.
A path on which SPouT loses precision (a method without symbolic implementation, e.g. `Math.sin`) or a solver
query without answer makes the verdict `DONT-KNOW` instead of `OK`.

| Variable | Default | Effect |
|---|---|---|
| `GDART_TIMEOUT` | 600 | DSE timeout (s) |
| `GDART_ERRORS_BUDGET` | 60 | time budget (s) of OPAL's analysis of the errors of constructors |
| `GDART_OPAL_THREADS` | (OPAL's choice) | threads of OPAL |
| `GDART_DSE_JVM_OPTS` | - | options of the JVM of DSE, e.g. `-Xmx8g` |
| `GDART_EXEC_LOG` | - | file: wall time of every execution of SPouT |
