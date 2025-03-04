AC_DEFUN([AX_DETECT_CLANG], [
AC_SUBST(CLANG_CXXFLAGS)
AC_SUBST(CLANG_LDFLAGS)
AC_SUBST(CLANG_LIBS)
AC_SUBST(CLANG_RFLAG)
AX_SUBMODULE(clang,system,system)
if test "x$with_clang_prefix" != "x"; then
	LLVM_CONFIG="$with_clang_prefix/bin/llvm-config"
fi
AC_PATH_PROG([LLVM_CONFIG], ["llvm-config"])
if test -z "$LLVM_CONFIG" || test ! -x "$LLVM_CONFIG"; then
	AC_MSG_ERROR([llvm-config not found])
fi
CLANG_CXXFLAGS=`$LLVM_CONFIG --cxxflags | \
	$SED -e 's/-Wcovered-switch-default//' \
	     -e 's/-gsplit-dwarf//' \
	     -e 's/-Wl,--no-keep-files-mapped//'`
CLANG_LDFLAGS=`$LLVM_CONFIG --ldflags`
# Construct a -R argument for libtool.
# This is needed in case some of the clang libraries are shared libraries.
CLANG_RFLAG=`echo "$CLANG_LDFLAGS" | $SED -e 's/-L/-R/g'`

CLANG_VERSION=`$LLVM_CONFIG --version`
CLANG_LIB="LLVM-$CLANG_VERSION"

SAVE_LDFLAGS="$LDFLAGS"
LDFLAGS="$CLANG_LDFLAGS $LDFLAGS"
AC_CHECK_LIB([$CLANG_LIB], [main], [have_lib_llvm=yes], [have_lib_llvm=no])
LDFLAGS="$SAVE_LDFLAGS"

# Use single libLLVM shared library when available.
# Otherwise, try and figure out all the required libraries
if test "$have_lib_llvm" = yes; then
	CLANG_LIBS="-l$CLANG_LIB"
else
	targets=`$LLVM_CONFIG --targets-built`
	components="$targets asmparser bitreader support mc"
	for c in option frontendopenmp; do
		$LLVM_CONFIG --components | $GREP $c > /dev/null 2> /dev/null
		if test $? -eq 0; then
			components="$components $c"
		fi
	done
	CLANG_LIBS=`$LLVM_CONFIG --libs $components`
fi
systemlibs=`$LLVM_CONFIG --system-libs 2> /dev/null | tail -1`
if test $? -eq 0; then
	CLANG_LIBS="$CLANG_LIBS $systemlibs"
fi
CLANG_PREFIX=`$LLVM_CONFIG --prefix`
AC_DEFINE_UNQUOTED(CLANG_PREFIX, ["$CLANG_PREFIX"], [Clang installation prefix])

AC_LANG_PUSH(C++)

SAVE_CPPFLAGS="$CPPFLAGS"
SAVE_LDFLAGS="$LDFLAGS"
SAVE_LIBS="$LIBS"

CPPFLAGS="$CLANG_CXXFLAGS -I$srcdir $CPPFLAGS"
AC_CHECK_HEADER([clang/Basic/SourceLocation.h], [],
	[AC_MSG_ERROR([clang header file not found])])
AC_CHECK_HEADER([llvm/TargetParser/Host.h],
	[AC_DEFINE([HAVE_TARGETPARSER_HOST_H], [],
		   [Define if llvm/TargetParser/Host.h exists])],
	[AC_EGREP_HEADER([getDefaultTargetTriple], [llvm/Support/Host.h], [],
		[AC_DEFINE([getDefaultTargetTriple], [getHostTriple],
		[Define to getHostTriple for older versions of clang])])
	])
AC_EGREP_HEADER([getExpansionLineNumber], [clang/Basic/SourceLocation.h], [],
	[AC_DEFINE([getExpansionLineNumber], [getInstantiationLineNumber],
	[Define to getInstantiationLineNumber for older versions of clang])])
AC_EGREP_HEADER([getExpansionColumnNumber], [clang/Basic/SourceLocation.h], [],
	[AC_DEFINE([getExpansionColumnNumber], [getInstantiationColumnNumber],
	[Define to getInstantiationColumnNumber for older versions of clang])])
AC_EGREP_HEADER([getExpansionLoc], [clang/Basic/SourceManager.h], [],
	[AC_DEFINE([getExpansionLoc], [getInstantiationLoc],
	[Define to getInstantiationLoc for older versions of clang])])
AC_EGREP_HEADER([DiagnosticConsumer], [clang/Basic/Diagnostic.h], [],
	[AC_DEFINE([DiagnosticConsumer], [DiagnosticClient],
	[Define to DiagnosticClient for older versions of clang])])
AC_EGREP_HEADER([DiagnosticsEngine], [clang/Basic/Diagnostic.h],
	[AC_DEFINE([DiagnosticInfo], [Diagnostic],
	[Define to Diagnostic for newer versions of clang])],
	[AC_DEFINE([DiagnosticsEngine], [Diagnostic],
	[Define to Diagnostic for older versions of clang])])
AC_EGREP_HEADER([ArrayRef], [clang/Driver/Driver.h],
	[AC_DEFINE([USE_ARRAYREF], [],
		[Define if Driver::BuildCompilation takes ArrayRef])
	AC_EGREP_HEADER([ArrayRef.*CommandLineArgs],
		[clang/Frontend/CompilerInvocation.h],
		[AC_DEFINE([CREATE_FROM_ARGS_TAKES_ARRAYREF], [],
			[Define if CompilerInvocation::CreateFromArgs takes
			 ArrayRef])
		])
	])
AC_EGREP_HEADER([getReturnType], [clang/AST/Decl.h], [],
	[AC_DEFINE([getReturnType], [getResultType],
	[Define to getResultType for older versions of clang])])
AC_EGREP_HEADER([CXXIsProduction], [clang/Driver/Driver.h],
	[AC_DEFINE([HAVE_CXXISPRODUCTION], [],
		[Define if Driver constructor takes CXXIsProduction argument])])
AC_EGREP_HEADER([ IsProduction], [clang/Driver/Driver.h],
	[AC_DEFINE([HAVE_ISPRODUCTION], [],
		[Define if Driver constructor takes IsProduction argument])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <clang/Driver/Driver.h>]], [[
	using namespace clang;
	DiagnosticsEngine *Diags;
	new driver::Driver("", "", "", *Diags);
]])], [AC_DEFINE([DRIVER_CTOR_TAKES_DEFAULTIMAGENAME], [],
	      [Define if Driver constructor takes default image name])])
AC_EGREP_HEADER([void HandleTopLevelDecl\(], [clang/AST/ASTConsumer.h],
	[AC_DEFINE([HandleTopLevelDeclReturn], [void],
		   [Return type of HandleTopLevelDeclReturn])
	 AC_DEFINE([HandleTopLevelDeclContinue], [],
		   [Return type of HandleTopLevelDeclReturn])],
	[AC_DEFINE([HandleTopLevelDeclReturn], [bool],
		   [Return type of HandleTopLevelDeclReturn])
	 AC_DEFINE([HandleTopLevelDeclContinue], [true],
		   [Return type of HandleTopLevelDeclReturn])])
AC_CHECK_HEADER([clang/Basic/DiagnosticOptions.h],
	[AC_DEFINE([HAVE_BASIC_DIAGNOSTICOPTIONS_H], [],
		   [Define if clang/Basic/DiagnosticOptions.h exists])])
AC_CHECK_HEADER([clang/Lex/HeaderSearchOptions.h],
	[AC_DEFINE([HAVE_LEX_HEADERSEARCHOPTIONS_H], [],
		   [Define if clang/Lex/HeaderSearchOptions.h exists])], [],
	[#include <clang/Basic/LLVM.h>])
AC_CHECK_HEADER([clang/Lex/PreprocessorOptions.h],
	[AC_DEFINE([HAVE_LEX_PREPROCESSOROPTIONS_H], [],
		   [Define if clang/Lex/PreprocessorOptions.h exists])], [],
	[#include <clang/Basic/LLVM.h>])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <clang/Basic/TargetInfo.h>]], [[
	using namespace clang;
	std::shared_ptr<TargetOptions> TO;
	DiagnosticsEngine *Diags;
	TargetInfo::CreateTargetInfo(*Diags, TO);
]])], [AC_DEFINE([CREATETARGETINFO_TAKES_SHARED_PTR], [],
	      [Define if TargetInfo::CreateTargetInfo takes shared_ptr])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[#include <clang/Basic/TargetInfo.h>]], [[
	using namespace clang;
	TargetOptions *TO;
	DiagnosticsEngine *Diags;
	TargetInfo::CreateTargetInfo(*Diags, TO);
]])], [AC_DEFINE([CREATETARGETINFO_TAKES_POINTER], [],
	      [Define if TargetInfo::CreateTargetInfo takes pointer])])
AC_EGREP_HEADER([getLangOpts], [clang/Lex/Preprocessor.h], [],
	[AC_DEFINE([getLangOpts], [getLangOptions],
	[Define to getLangOptions for older versions of clang])])
AC_EGREP_HEADER([findLocationAfterToken], [clang/Lex/Lexer.h],
	[AC_DEFINE([HAVE_FINDLOCATIONAFTERTOKEN], [],
	[Define if SourceManager has findLocationAfterToken method])])
AC_EGREP_HEADER([translateLineCol], [clang/Basic/SourceManager.h],
	[AC_DEFINE([HAVE_TRANSLATELINECOL], [],
	[Define if SourceManager has translateLineCol method])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
		[[#include <clang/Frontend/CompilerInstance.h>]], [[
	using namespace clang;
	DiagnosticConsumer *client;
	CompilerInstance *Clang;
	Clang->createDiagnostics(client);
]])], [], [AC_DEFINE([CREATEDIAGNOSTICS_TAKES_ARG], [],
	[Define if CompilerInstance::createDiagnostics takes argc and argv])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
		[[#include <clang/Lex/HeaderSearchOptions.h>]], [[
	using namespace clang;
	HeaderSearchOptions HSO;
	HSO.AddPath("", frontend::Angled, false, false);
]])], [AC_DEFINE([ADDPATH_TAKES_4_ARGUMENTS], [],
	[Define if HeaderSearchOptions::AddPath takes 4 arguments])])
AC_EGREP_HEADER([getLocWithOffset], [clang/Basic/SourceLocation.h], [],
	[AC_DEFINE([getLocWithOffset], [getFileLocWithOffset],
	[Define to getFileLocWithOffset for older versions of clang])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
		[[#include <clang/Frontend/CompilerInstance.h>]], [[
	using namespace clang;
	CompilerInstance *Clang;
	Clang->createPreprocessor(TU_Complete);
]])], [AC_DEFINE([CREATEPREPROCESSOR_TAKES_TUKIND], [],
[Define if CompilerInstance::createPreprocessor takes TranslationUnitKind])])
AC_EGREP_HEADER([DecayedType], [clang/AST/Type.h],
	[AC_DEFINE([HAVE_DECAYEDTYPE], [], [Define if DecayedType is defined])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM(
		[[#include <clang/Basic/SourceManager.h>]], [[
	using namespace clang;
	SourceManager* sm;
	SourceLocation* loc;
	SrcMgr::CharacteristicKind* c_kind;
	const FileEntry* entry;
	sm->createFileID(entry, *loc, *c_kind);
]])], [], [AC_DEFINE([CEATEFILEID_TAKES_FILEENTRYREF_ONLY], [],
	[Define if SourceManager::createFileID takes FileEntryRef only])])
AC_EGREP_HEADER([setMainFileID], [clang/Basic/SourceManager.h],
	[AC_DEFINE([HAVE_SETMAINFILEID], [],
	[Define if SourceManager has a setMainFileID method])])
AC_CHECK_HEADER([llvm/ADT/OwningPtr.h],
	[AC_DEFINE([HAVE_ADT_OWNINGPTR_H], [],
		   [Define if llvm/ADT/OwningPtr.h exists])])
AC_EGREP_HEADER([TypeInfo getTypeInfo], [clang/AST/ASTContext.h],
	[AC_DEFINE([GETTYPEINFORETURNSTYPEINFO], [],
		[Define if getTypeInfo returns TypeInfo object])])
AC_EGREP_HEADER([TypedefNameDecl], [clang/AST/Type.h], [],
	[AC_DEFINE([TypedefNameDecl], [TypedefDecl],
		[Define to TypedefDecl for older versions of clang])
	 AC_DEFINE([getTypedefNameForAnonDecl], [getTypedefForAnonDecl],
		[Define to getTypedefForAnonDecl for older versions of clang])])
AC_EGREP_HEADER([StmtRange], [clang/AST/StmtIterator.h],
	[AC_DEFINE([HAVE_STMTRANGE], [],
	[Define if StmtRange class is available])])
AC_EGREP_HEADER([initializeBuiltins],
	[clang/Basic/Builtins.h], [],
	[AC_DEFINE([initializeBuiltins], [InitializeBuiltins],
		[Define to InitializeBuiltins for older versions of clang])])
AC_EGREP_HEADER([IK_C], [clang/Frontend/FrontendOptions.h], [],
	[AC_CHECK_HEADER([clang/Basic/LangStandard.h],
		[IK_C=Language::C], [IK_C=InputKind::C])
	 AC_DEFINE_UNQUOTED([IK_C], [$IK_C],
	 [Define to Language::C or InputKind::C for newer versions of clang])
	])
# llvmorg-15-init-7544-g93471e65df48
AC_EGREP_HEADER([setLangDefaults], [clang/Basic/LangOptions.h],
	[SETLANGDEFAULTS=LangOptions],
	[SETLANGDEFAULTS=CompilerInvocation])
AC_DEFINE_UNQUOTED([SETLANGDEFAULTS], [$SETLANGDEFAULTS],
	[Define to class with setLangDefaults method])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
	#include <clang/Basic/TargetOptions.h>
	#include <clang/Lex/PreprocessorOptions.h>
	#include <clang/Frontend/CompilerInstance.h>

	#include "set_lang_defaults_arg4.h"
]], [[
	using namespace clang;
	CompilerInstance *Clang;
	TargetOptions TO;
	llvm::Triple T(TO.Triple);
	PreprocessorOptions PO;
	SETLANGDEFAULTS::setLangDefaults(Clang->getLangOpts(), IK_C,
			T, setLangDefaultsArg4(PO),
			LangStandard::lang_unspecified);
]])], [AC_DEFINE([SETLANGDEFAULTS_TAKES_5_ARGUMENTS], [],
	[Define if CompilerInvocation::setLangDefaults takes 5 arguments])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
	#include <clang/Frontend/CompilerInstance.h>
	#include <clang/Frontend/CompilerInvocation.h>
]], [[
	using namespace clang;
	CompilerInvocation *invocation;
	CompilerInstance *Clang;
	Clang->setInvocation(std::make_shared<CompilerInvocation>(*invocation));
]])], [AC_DEFINE([SETINVOCATION_TAKES_SHARED_PTR], [],
	[Defined if CompilerInstance::setInvocation takes a shared_ptr])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
	#include <clang/AST/Decl.h>
]], [[
	clang::FunctionDecl *fd;
	fd->getBeginLoc();
	fd->getEndLoc();
]])],
	[AC_DEFINE([HAVE_BEGIN_END_LOC], [],
		[Define if getBeginLoc and getEndLoc should be used])])
AC_CHECK_HEADER([llvm/Option/Arg.h],
	[AC_DEFINE([HAVE_LLVM_OPTION_ARG_H], [],
		   [Define if llvm/Option/Arg.h exists])])
AC_EGREP_HEADER([PragmaIntroducer ],
	[clang/Lex/Pragma.h], [],
	[AC_DEFINE([PragmaIntroducer], [PragmaIntroducerKind],
		[Define to PragmaIntroducerKind for older versions of clang])])
AC_CHECK_HEADER([clang/Basic/LangStandard.h],
	[AC_DEFINE([HAVE_CLANG_BASIC_LANGSTANDARD_H], [],
		   [Define if clang/Basic/LangStandard.h exists])])
AC_EGREP_HEADER([setDiagnosticGroupWarningAsError], [clang/Basic/Diagnostic.h],
	[AC_DEFINE([HAVE_SET_DIAGNOSTIC_GROUP_WARNING_AS_ERROR], [],
	[Define if DiagnosticsEngine::setDiagnosticGroupWarningAsError \
	is available])])
# llvmorg-15-init-8223-g7d644e1215b3
AC_EGREP_HEADER([ext_implicit_function_decl_c99],
		[clang/Basic/DiagnosticCategories.h], [],
	[AC_DEFINE([ext_implicit_function_decl_c99],
	[ext_implicit_function_decl],
	[Define to ext_implicit_function_decl for older versions of clang])])
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
	#include <clang/AST/Type.h>
]], [[
	sizeof(::clang::ArrayType::Static);
]])],
	[AC_DEFINE([CLANG_ARRAY_SIZE_MODIFIER], [::clang::ArrayType],
		[Define if ArraySizeModifier is inside ArrayType])],
	[AC_DEFINE([CLANG_ARRAY_SIZE_MODIFIER], [::clang::ArraySizeModifier],
		[Define if ArraySizeModifier is an enum class inside clang])])

LDFLAGS="$CLANG_LDFLAGS $LDFLAGS"

# A test program for checking whether linking against libclang-cpp works.
m4_define([_AX_DETECT_CLANG_PROGRAM], [AC_LANG_PROGRAM(
	[[#include <clang/Frontend/CompilerInstance.h>]],
	[[
		new clang::CompilerInstance();
	]])])

# Use single libclang-cpp shared library when available.
# Otherwise, use a selection of clang libraries that appears to work.
AC_CHECK_LIB([clang-cpp], [main], [have_lib_clang=yes], [have_lib_clang=no])
if test "$have_lib_clang" = yes; then
	# The LLVM libraries may be linked into libclang-cpp already.
	# Linking against them again can cause errors about options
	# being registered more than once.
	# Check whether linking against libclang-cpp requires
	# linking against the LLVM libraries as well.
	# Fail if linking fails with or without the LLVM libraries.
	AC_MSG_CHECKING([whether libclang-cpp needs LLVM libraries])
	LIBS="-lclang-cpp $SAVE_LIBS"
	AC_LINK_IFELSE([_AX_DETECT_CLANG_PROGRAM], [clangcpp_needs_llvm=no], [
		LIBS="-lclang-cpp $CLANG_LIBS $SAVE_LIBS"
		AC_LINK_IFELSE([_AX_DETECT_CLANG_PROGRAM],
			[clangcpp_needs_llvm=yes],
			[clangcpp_needs_llvm=unknown])
	])
	AC_MSG_RESULT([$clangcpp_needs_llvm])
	AS_IF([test "$clangcpp_needs_llvm" = "no"],
			[CLANG_LIBS="-lclang-cpp"],
	      [test "$clangcpp_needs_llvm" = "yes"],
			[CLANG_LIBS="-lclang-cpp $CLANG_LIBS"],
	      [AC_MSG_FAILURE([unable to link against libclang-cpp])])
else
	CLANG_LIBS="-lclangBasic -lclangDriver $CLANG_LIBS"
	CLANG_LIBS="-lclangAnalysis -lclangAST -lclangLex $CLANG_LIBS"
	LDFLAGS="$CLANG_LDFLAGS $CLANG_LIBS $SAVE_LDFLAGS"
	AC_CHECK_LIB([clangEdit], [main], [LIB_CLANG_EDIT=-lclangEdit], [])
	CLANG_LIBS="$LIB_CLANG_EDIT $CLANG_LIBS"
	CLANG_LIBS="-lclangParse -lclangSema $CLANG_LIBS"
	CLANG_LIBS="-lclangFrontend -lclangSerialization $CLANG_LIBS"
fi

CPPFLAGS="$SAVE_CPPFLAGS"
LDFLAGS="$SAVE_LDFLAGS"
LIBS="$SAVE_LIBS"

AC_LANG_POP
])
