#
# spec file for package test-quote-char
#
# Copyright (c) 2013-2015 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:		test-quote-char
Version:	1.0
Release:	1
BuildArch:	noarch
License:	GPL-3.0
Summary:	Test package with quote character in filename
Group:		Development
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Test package with quote character in filename

%prep
mkdir -p %{buildroot}"/opt/test-quote-char/test-dir-name-with-' quote-char '"
touch %{buildroot}"/opt/test-quote-char/test-dir-name-with-' quote-char '/test-file-name-with-' quote-char '"
touch %{buildroot}"/opt/test-quote-char/link"
touch %{buildroot}"/opt/test-quote-char/target-with-quote'-foo"


%files
%defattr(-,root,root)
/opt/test-quote-char

%changelog

