(*
 * Copyright (c) 2013-2020 Thomas Gazagnaire <thomas@gazagnaire.org>
 * Copyright (c) 2013-2020 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2015-2020 Gabriel Radanne <drupyog@zoho.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

type t = {
  depext : bool;
  build_dir : Fpath.t;
  builder_name : string;
  unikernel_opam_name : Misc.Name.Opam.t;
  extra_repo : (string * string) list;
  config_file : Fpath.t;
}

let v ?(extra_repo = []) ~build_dir ~builder_name ~depext ~config_file
    unikernel_opam_name =
  {
    depext;
    build_dir;
    builder_name;
    unikernel_opam_name;
    extra_repo;
    config_file;
  }

let depext_rules =
  {|
depext-lockfile: $(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam.locked
	echo " ↳ install external dependencies for monorepo"
	env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo depext -y -l $<
|}

let opam_repo_add_rule extra =
  let buf = Buffer.create 0x100 in
  let ppf = Format.formatter_of_buffer buf in
  Fmt.pf ppf
    {|repo-add:
	@@printf "\e[2musing overlay repository mirage: %a \e[0m\n"
|}
    Fmt.(brackets (list ~sep:(any ", ") (using fst string)))
    extra;
  List.iter
    (fun (name, repo) ->
      Fmt.pf ppf "\t$(OPAM) repo add %s %s || $(OPAM) repo set-url %s %s\n" name
        repo name repo)
    extra;
  Buffer.contents buf

let opam_repo_remove_rule extra =
  let buf = Buffer.create 0x100 in
  let ppf = Format.formatter_of_buffer buf in
  Fmt.pf ppf
    {|repo-rm:
	@@printf "\e[2mremoving overlay repository %a\e[0m\n"
|}
    Fmt.(brackets (list ~sep:(any ", ") (using fst string)))
    extra;
  List.iter
    (fun (name, repo) -> Fmt.pf ppf "\t$(OPAM) repo remove %s %s\n" name repo)
    extra;
  Buffer.contents buf

let pp_extra_rules ppf t =
  let rules, targets =
    match t.depext with
    | true -> ([ depext_rules ], [ "depext-lockfile" ])
    | false -> ([], [])
  in
  let rules, targets =
    match t.extra_repo with
    | _ :: _ as extra ->
        ( opam_repo_add_rule extra :: opam_repo_remove_rule extra :: rules,
          "repo-add" :: "repo-rm" :: targets )
    | [] -> (rules, targets)
  in
  match rules with
  | [] -> ()
  | _ ->
      Fmt.pf ppf " %a\n\n"
        (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf " ") Fmt.string)
        targets;
      Fmt.pf ppf "%a"
        (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf "\n\n") Fmt.string)
        rules

let pp ppf t =
  let mirage_dir = Fpath.(t.build_dir / t.builder_name) in
  let pp_depext_lockfile ppf = function
    | true -> Fmt.string ppf "\n\t@$(MAKE) -s depext-lockfile"
    | false -> ()
  and pp_no_depext ppf = function
    | true -> ()
    | false -> Fmt.string ppf " --no-depexts"
  and pp_add_repo ppf = function
    | _ :: _ -> Fmt.string ppf "\n\t@$(MAKE) -s repo-add"
    | [] -> ()
  and pp_or_remove_repo ppf = function
    | _ :: _ -> Fmt.string ppf "; (ret=$$?; $(MAKE) -s repo-rm && exit $$ret)"
    | [] -> ()
  in
  Fmt.pf ppf
    {|-include Makefile.user
BUILD_DIR = %a
MIRAGE_DIR = %a
UNIKERNEL_NAME = %s
OPAM = opam

all::
	@@$(MAKE) --no-print-directory depends
	@@$(MAKE) --no-print-directory build

.PHONY: all lock install-switch pull clean depend depends build%a

$(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam.locked: $(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam%a
	@@echo " ↳ generate lockfile for monorepo dependencies"
	@@env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo lock --require-cross-compile --build-only $(UNIKERNEL_NAME) -l $@@ --ocaml-version $(shell ocamlc --version)%a

lock::
	@@$(MAKE) -B $(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam.locked

pull:: $(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam.locked
	@@echo " ↳ fetch monorepo dependencies in the duniverse folder"
	@@env OPAMVAR_monorepo="opam-monorepo" $(OPAM) monorepo pull -l $< -r $(abspath $(BUILD_DIR))

install-switch:: $(MIRAGE_DIR)/$(UNIKERNEL_NAME).opam
	@@echo " ↳ opam install switch dependencies"
	@@$(OPAM) install $< --deps-only --yes%a%a

depends depend::
	@@$(MAKE) --no-print-directory lock
	@@$(MAKE) --no-print-directory install-switch
	@@$(MAKE) --no-print-directory pull

build::
	mirage build -f %a

clean::
	mirage clean
|}
    Fpath.pp t.build_dir Fpath.pp mirage_dir
    (Misc.Name.Opam.to_string t.unikernel_opam_name)
    pp_extra_rules t pp_add_repo t.extra_repo pp_or_remove_repo t.extra_repo
    pp_no_depext t.depext pp_depext_lockfile t.depext Fpath.pp t.config_file
