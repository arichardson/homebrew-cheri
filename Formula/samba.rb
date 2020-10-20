# See rejected pull request https://github.com/Homebrew/homebrew-core/pull/32031

class Samba < Formula
  desc "SMB/CIFS file server for UNIX (this is only useful for QEMU user-network shares)"
  homepage "https://samba.org/"
  url "https://download.samba.org/pub/samba/stable/samba-4.12.8.tar.gz"
  sha256 "6b2078c0d451e442b0e3c194f7b14db684fe374651cc2057ce882f0614925f2d"

  keg_only :provided_by_macos
  depends_on "pkg-config" => :build
  depends_on "python" => :build
  depends_on "gnutls"
  depends_on "jansson"
  depends_on "krb5"
  depends_on "libarchive"
  depends_on "openssl"
  depends_on "readline" # Without the readline dependency the build fails on macOS 10.14+

  resource "Parse::Yapp" do
    url "https://cpan.metacpan.org/authors/id/W/WB/WBRASWELL/Parse-Yapp-1.21.tar.gz"
    sha256 "3810e998308fba2e0f4f26043035032b027ce51ce5c8a52a8b8e340ca65f13e5"
  end

  # Fixes the Grouplimit of 16 users os OS X.
  # https://bugzilla.samba.org/show_bug.cgi?id=8773
  # https://github.com/samba-team/samba/pull/210
  patch :DATA

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
           "--without-gettext",
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
    sbin.install_symlink "smbd" => "samba-dot-org-smbd"
  end

  def post_install
    # Add a symlink so that the QEMU formula finds this smdb by default
    (HOMEBREW_PREFIX/"sbin").install_symlink (sbin/"samba-dot-org-smbd").realpath
  end

  test do
    system "#{sbin}/smbd", "--version"
    system "#{sbin}/smbd", "--help"
  end
end
__END__
commit a483985e25d101c1b7a0b3a0a74525427d0aa385
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

diff --git a/buildtools/wafsamba/wscript b/buildtools/wafsamba/wscript
index f0b679257b7..a589ecdb114 100644
--- a/buildtools/wafsamba/wscript
+++ b/buildtools/wafsamba/wscript
@@ -497,7 +497,10 @@ struct foo bar = { .y = 'X', .x = 1 };
     conf.CHECK_HEADERS('strings.h inttypes.h stdint.h unistd.h minix/config.h', add_headers=True)
     conf.CHECK_HEADERS('ctype.h', add_headers=True)
 
-    if sys.platform != 'darwin':
+    if sys.platform == 'darwin':
+        conf.DEFINE('_DARWIN_C_SOURCE', 1, add_to_cflags=True)
+        conf.DEFINE('_DARWIN_UNLIMITED_GETGROUPS', 1, add_to_cflags=True)
+    else:
         conf.CHECK_HEADERS('standards.h', add_headers=True)
 
     conf.CHECK_HEADERS('stdbool.h stdint.h stdarg.h vararg.h', add_headers=True)
diff --git a/source3/lib/system.c b/source3/lib/system.c
index f1265e0c43f..ef8bd56a5a9 100644
--- a/source3/lib/system.c
+++ b/source3/lib/system.c
@@ -844,7 +844,18 @@ void sys_srandom(unsigned int seed)
 
 int groups_max(void)
 {
-#if defined(SYSCONF_SC_NGROUPS_MAX)
+#if defined(DARWINOS)
+	/*
+	 * On MacOS sysconf(_SC_NGROUPS_MAX) returns 16 due to MacOS's group
+	 * nesting. However, The initgroups() manpage states the following:
+	 * "Note that OS X supports group mem bership in an unlimited number
+	 * of groups. The OS X kernel uses the group list stored in the process
+	 * credentials only as an initial cache.  Additional group memberships
+	 * are determined by communication between the operating system and the
+	 * opendirectoryd daemon."
+	 */
+	return GID_MAX;
+#elif defined(SYSCONF_SC_NGROUPS_MAX)
 	int ret = sysconf(_SC_NGROUPS_MAX);
 	return (ret == -1) ? NGROUPS_MAX : ret;
 #else
@@ -856,8 +867,8 @@ int groups_max(void)
  Wrap setgroups and getgroups for systems that declare getgroups() as
  returning an array of gid_t, but actuall return an array of int.
 ****************************************************************************/
-
 #if defined(HAVE_BROKEN_GETGROUPS)
+#error "Cannot build on macos with HAVE_BROKEN_GETGROUPS"
 
 #ifdef HAVE_BROKEN_GETGROUPS
 #define GID_T int
diff --git a/source3/smbd/sec_ctx.c b/source3/smbd/sec_ctx.c
index 5e0710e0ecb..89e9bbdaff9 100644
--- a/source3/smbd/sec_ctx.c
+++ b/source3/smbd/sec_ctx.c
@@ -282,7 +282,8 @@ static void set_unix_security_ctx(uid_t uid, gid_t gid, int ngroups, gid_t *grou
 
 static void set_unix_security_ctx(uid_t uid, gid_t gid, int ngroups, gid_t *groups)
 {
-	int max = groups_max();
+	_Static_assert(NGROUPS_MAX == 16, "initgroups manpage no longer correct?");
+	int max = NGROUPS_MAX; // groups_max();
 
 	/* Start context switch */
 	gain_root();
diff --git a/source3/wscript b/source3/wscript
index 85466b493fa..662406425d2 100644
--- a/source3/wscript
+++ b/source3/wscript
@@ -477,6 +477,9 @@ vsyslog
         conf.DEFINE('DARWINOS', 1)
         conf.ADD_CFLAGS('-fno-common')
         conf.DEFINE('STAT_ST_BLOCKSIZE', '512')
+        # getgrouplist_2() can be used to determine the real maximum number of
+        # groups on macOS since getgrouplist() is limited to 16.
+        conf.CHECK_FUNCS('getgrouplist_2')
     elif (host_os.rfind('freebsd') > -1):
         conf.DEFINE('FREEBSD', 1)
         if conf.CHECK_HEADERS('sunacl.h'):
