Check that configure generates the file in the right dir when `--file`
is passed:

  $ ./test.exe configure -v --file app/config.ml
  test.exe: [INFO] run: configure:
                        { "args" =
                           { "context" = ;
                             "config_file" = app/config.ml;
                             "output" = None;
                             "dry_run" = false };
                          "depext" = true }
  test.exe: [INFO] Compiling: app/config.ml
  test.exe: [INFO] Preserving arguments in app/test.context:
                   [|"./test.exe"; "configure"; "-v"; "--file";
                     "app/config.ml"|]
  config.exe: [INFO] Name       noop
                     Keys      
                       hello=Hello World! (default),
                       vote=cat (default),
                       warn_error=false (default)
  config.exe: [INFO] Configuration: app/config.ml
  config.exe: [INFO] Generating: main.ml (main file)
  config.exe: [INFO] Generating: key_gen.ml (keys)
  test.exe: [INFO] Generating: noop.opam
  test.exe: [INFO] Generating: noop.install
  $ ls -a app/
  .
  ..
  app.ml
  config.ml
  dune
  dune.build
  dune.config
  key_gen.ml
  main.ml
  test.context
  $ ./test.exe clean --file app/config.ml

Check that configure create the correctcontext file:

  $ ./test.exe configure --file=app/config.ml
  $ cat app/test.context
  configure
  --file=app/config.ml
  $ rm -rf custom_build_

  $ ./test.exe configure --file=app/config.ml
  $ cat app/test.context
  configure
  --file=app/config.ml
  $ ./test.exe clean --file=app/config.ml

Check that `test help configure` and `test configure --help` have the
same output.

  $ ./test.exe help configure --file=app/config.ml --help=plain > h1
  $ ./test.exe configure --help=plain --file=app/config.ml > h2
  $ ./help.exe diff h1 h2

Check that `test help configure` works when no config.ml file is present.

  $ ./test.exe configure --help=plain > h0
  $ ./help.exe show h0 SYNOPSIS | xargs
  test configure [OPTION]...
