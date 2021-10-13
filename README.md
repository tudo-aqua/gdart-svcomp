# The GDart tool

GDart is a tool ensemble for the dynamic symbolic execution of modern Java.
GDart consists of three components:
- DSE a generic dynamic symbolic execution (https://github.com/tudo-aqua/dse)
- SPouT: Symbolic Path Recording During Testing (https://github.com/tudo-aqua/spout)
- JConstraints: A meta solving library for SMT problems (https://github.com/tudo-aqua/jconstraints)

To verify a a SV-COMP benchmark example, just call the ./run-gdart.sh script:
`./run-gdart.sh property path_to_java_common path_to_folder_containint_Main_class`

GDart runs on MacOS and Ubuntu 20.04. Windows is currently not supported.
