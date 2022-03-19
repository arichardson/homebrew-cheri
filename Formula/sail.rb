class Sail < Formula
  desc "Language for describing the instruction semantics of processors"
  homepage "https://www.cl.cam.ac.uk/~pes20/sail/"
  url "https://github.com/rems-project/sail/archive/0.14.tar.gz"
  sha256 "c4c05563b51d20a442a8b203e27cfff8bfab16eda51b5bbb1cc880860ecf4347"
  head "https://github.com/rems-project/sail.git", branch: "sail2"

  depends_on "gmp" => :build
  depends_on "opam" => :build
  depends_on "pkg-config" => :build
  depends_on "z3" => :build
  depends_on "ocaml"

  def install
    Dir.mktmpdir("opamroot") do |opamroot|
      ENV["OPAMROOT"] = opamroot
      ENV["OPAMYES"] = "1"
      ENV["OPAMJOBS"] = ENV.make_jobs.to_s
      ENV["ADD_REVISION"] = "1" if build.head?
      system "opam", "init", "--no-setup", "--disable-sandboxing"
      # These binaries are provided by homebrew so install them with --fake
      # Note: --fake also fakes the dependencies so we first install them with --deps-only
      # system "opam", "install", "--deps-only", "ott", "menhir"
      # system "opam", "install", "--fake", "ott", "menhir"
      system "time", "opam", "repository", "add", "rems", "https://github.com/rems-project/opam-repository.git"
      ENV["OPAMJOBS"] = ENV.make_jobs.to_s
      system "opam", "list", "-i"
      # just use opam to install from the source dir
      # use opam to install sail (pin first to build it from the sources instead of the repo)
      system "opam", "install", ".", "--deps-only", prefix.to_s
      # system "opam", "install", ".", "--inplace-build", "--destdir", prefix.to_s
      system "opam", "config", "exec", "make", "isail", "INSTALL_DIR=#{prefix}", "SHARE_DIR=#{share}"
      system "opam", "config", "exec", "make", "install", "INSTALL_DIR=#{prefix}", "SHARE_DIR=#{share}"
    end
  end

  test do
    system "#{bin}/sail", "-v"
  end
end
