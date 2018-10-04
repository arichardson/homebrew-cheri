class Sail < Formula
  desc "Language for describing the instruction semantics of processors"
  homepage "https://www.cl.cam.ac.uk/~pes20/sail/"
  url "https://github.com/rems-project/sail/archive/0.3.tar.gz"
  sha256 "cb27a4791283a153c5795de1ba3d5c97ac918e8113066245d6f8a8b9f040bcb6"
  head "https://github.com/rems-project/sail.git", :branch => "sail2"

  depends_on "gmp" => :build
  depends_on "menhir" => :build
  depends_on "opam" => :build
  depends_on "ott" => :build
  depends_on "z3" => :build
  depends_on "ocaml"

  def install
    Dir.mktmpdir("opamroot") do |opamroot|
      ENV["OPAMROOT"] = opamroot
      ENV["OPAMYES"] = "1"
      # ENV["OCAMLPARAM"] = "safe-string=0,_" # OCaml 4.06.0 compat
      ENV["OPAMJOBS"] = ENV.make_jobs.to_s
      system "opam", "init", "--no-setup", "--disable-sandboxing"
      # These binaries are provided by homebrew so install them with --fake
      # Note: --fake also fakes the dependencies so we first install them with --deps-only
      system "opam", "install", "--deps-only", "ott", "menhir"
      system "opam", "install", "--fake", "ott", "menhir"
      system "opam", "list", "-i"
      # just use opam to install from the source dir
      if build.head?
        # When building the HEAD revision also pull in lem+linksem HEAD directly from GitHub
        system "opam", "pin", "add", "lem", "https://github.com/rems-project/lem.git"
        system "opam", "pin", "add", "linksem", "https://github.com/rems-project/linksem.git"
      else
        system "opam", "repository", "add", "rems", "https://github.com/rems-project/opam-repository.git"
      end
      # use opam to install sail (pin first to build it from the sources instead of the repo)
      system "opam", "pin", "--kind", "path", "add", "sail", ".", "-n"
      system "opam", "install", "sail", "--destdir", prefix.to_s
    end
  end

  test do
    system "#{bin}/sail", "-v"
  end
end
