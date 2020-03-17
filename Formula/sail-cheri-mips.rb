class SailCheriMips < Formula
  desc "Sail generated simulators for the MIPS and CHERI architecture"
  homepage "https://www.cl.cam.ac.uk/~pes20/sail/"
  # url "https://github.com/rems-project/sail/archive/0.3.tar.gz"
  # sha256 "cb27a4791283a153c5795de1ba3d5c97ac918e8113066245d6f8a8b9f040bcb6"
  head "https://github.com/CTSRD-CHERI/sail-cheri-mips.git"

  depends_on "gmp" => :build
  # depends_on "menhir" => :build
  depends_on "opam" => :build
  depends_on "sail" => :build
  depends_on "lem" => :build
  depends_on "linksem" => :build
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
#      system "opam", "install", "--deps-only", "ott", "menhir"
#      system "opam", "install", "--fake", "ott", "menhir"
      system "opam", "list", "-i"
      # system "opam", "install", "zarith"
      # system "opam", "list", "-i"
      system "time", "opam", "repository", "add", "rems", "https://github.com/arichardson/opam-repository.git"
      system "opam", "list", "-i"
      system "opam", "install", "lem", "linksem"

      system "opam", "exec", "--", "make", "all",
             "SAIL=#{Formula["sail"].opt_bin}/sail",
             "SAIL_DIR=#{Formula["sail"].opt_prefix}/share/sail"
      system "opam", "exec", "--", "make", "INSTALL_DIR=#{prefix}", "install"
    end
  end

  test do
    system "#{bin}/sail-cheri_c", "--help"
  end
end
