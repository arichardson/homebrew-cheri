# See rejected pull request https://github.com/Homebrew/homebrew-core/pull/32031

class Samba < Formula
  desc "SMB/CIFS file server for UNIX (this build is only useful for QEMU user-network shares)"
  homepage "https://samba.org/"
  url "https://download.samba.org/pub/samba/stable/samba-4.9.18.tar.gz"
  sha256 "c6d23982b7233ce8bc0c87b8b03585d782ddf3bd7c634c1ffa853d7d397d87f7"

  keg_only :provided_by_macos
  depends_on "pkg-config" => :build
  depends_on "python" => :build
  depends_on "jansson"
  depends_on "gnutls"
  depends_on "krb5"
  depends_on "libarchive"
  depends_on "openssl"
  depends_on "readline" # Without the readline dependency the build fails on macOS 10.14+

  resource "Parse::Yapp" do
    url "https://cpan.metacpan.org/authors/id/W/WB/WBRASWELL/Parse-Yapp-1.21.tar.gz"
    sha256 "3810e998308fba2e0f4f26043035032b027ce51ce5c8a52a8b8e340ca65f13e5"
  end

  def install
    # Add perl dependencies
    ENV.prepend_create_path "PERL5LIB", libexec/"lib/perl5"
    resources.each do |r|
      r.stage do
        system "perl", "Makefile.PL", "INSTALL_BASE=#{libexec}"
        system "make"
        system "make", "install"
      end
    end
    ENV.prepend_path "PATH", libexec/"bin"

    # Samba can be used to share directories with the guest in QEMU user-mode (SLIRP) networking
    # with the `-net user,id=net0,smb=/share/this/with/guest` option.
    # Without this formula QEMU will attempt use the system smbd and silently fail to setup
    # the share. By building samba.org sources as a keg-only formula we can use it as an
    # optional dependency for QEMU.
    system "./configure",
           "--disable-cephfs",
           "--disable-cups",
           "--disable-iprint",
           "--disable-glusterfs",
           "--disable-python",
           "--without-acl-support",
           "--without-ad-dc",
           "--without-ads",
           "--without-dnsupdate",
           "--without-ldap",
           "--without-ntvfs-fileserver",
           "--without-pam",
           "--without-quotas",
           "--without-regedit",
           "--without-syslog",
           "--without-utmp",
           "--without-winbind",
           # samba requires krb5 version 1.9+ so we can't use the system version
           "--with-system-mitkrb5", Formula["krb5"].opt_prefix.to_s,
           # The following libraries are not installed correctly so tell the build system to build them static:
           # Unfortunately this causes smbd to trap at runtime, so as a workaround manually install the dylibs
           # "--builtin-libraries=ldb,talloc,tdb,tevent",
           "--prefix=#{prefix}"
    system "make"
    system "make", "install"
    # The following libraries are not installed into the prefix by make install:
    copy_file "./bin/default/lib/ldb/libldb.dylib", "#{lib}/libldb.dylib"
    copy_file "./bin/default/lib/talloc/libtalloc.dylib", "#{lib}/libtalloc.dylib"
    copy_file "./bin/default/lib/tdb/libtdb.dylib", "#{lib}/libtdb.dylib"
    copy_file "./bin/default/lib/tevent/libtevent.dylib", "#{lib}/libtevent.dylib"
    sbin.install_symlink "smbd" => "samba-dot-org-smbd"
  end

  def post_install
    # Add a symlink so that the QEMU formula finds this smdb by default
    (HOMEBREW_PREFIX/"sbin").install_symlink (sbin/"samba-dot-org-smbd").realpath
  end

  # Fixes the Grouplimit of 16 users os OS X.
  # https://bugzilla.samba.org/show_bug.cgi?id=8773
  # https://github.com/samba-team/samba/pull/210
  patch :DATA

  test do
    system "#{sbin}/smbd", "--version"
    system "#{sbin}/smbd", "--help"
  end
end
__END__
commit 9d47ed6850545cd9315ef01f288b39c54e882cfb
Author: Alex Richardson <Alexander.Richardson@cl.cam.ac.uk>
Date:   Fri Oct 5 09:35:40 2018 +0100

    Don't use sysconf(_SC_NGROUPS_MAX) MacOS

    On MacOS sysconf(_SC_NGROUPS_MAX) always returns 16. However, this is not
    the value used by getgroups(2). MacOS uses nested groups but getgroups(2)
    will return the flattened list which can easily exceed 16 groups. In my
    testing getgroups() already returns 16 groups on a freshly installed
    system. And on a 10.14 system the root user is in more than 16 groups by
    default which makes it impossible to run smbd without this change.

    See https://bugzilla.samba.org/show_bug.cgi?id=8773

diff --git a/source3/lib/system.c b/source3/lib/system.c
index 507d4a9af93..4c6808a7637 100644
--- a/source3/lib/system.c
+++ b/source3/lib/system.c
@@ -776,7 +776,18 @@ void sys_srandom(unsigned int seed)

 int groups_max(void)
 {
-#if defined(SYSCONF_SC_NGROUPS_MAX)
+#if defined(DARWINOS)
+	/*
+	 * On MacOS sysconf(_SC_NGROUPS_MAX) returns 16
+	 * due to MacOS's group nesting. However, getgroups()
+	 * will return a flat list and return -1 if that flat list
+	 * exceeds the limit of 16 (which seems to be the case for
+	 * the root user on any 10.14 system). Since the sysconf()
+	 * constant is not related to what getgroups() uses we
+	 * return a fixed constant here.
+	 */
+	return 128;
+#elif defined(SYSCONF_SC_NGROUPS_MAX)
 	int ret = sysconf(_SC_NGROUPS_MAX);
 	return (ret == -1) ? NGROUPS_MAX : ret;
 #else
