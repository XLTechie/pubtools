#!/usr/bin/perl
#
# markdowntoc V1.0
#
# Makes headings in a markdown document into a table of contents at the top (or, optionally, somewhere else).
# Intended for use with Github wikis.
# Before use, make adjustments in the CONFIGURATION section.
# See also the THINGS TO KNOW section.
#
# Copyright (C) 2019 Luke Davis <newanswertech@gmail.com>, all rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
#
# This script has been tested with a very specific set of github wikis. It has not been widely tested at all.
# In other words: Make backups!
# This script took initial inspiration from an article written by Grant Winney, at <https://grantwinney.com/5-things-you-can-do-with-a-locally-cloned-github-wiki/>.
#
# Changelog:
# V1.0: initial stable release (6/5/2019)

### THINGS TO KNOW ###

# Usage:
# markdowntoc.pl file1.md [ file2.md ... fileN.md ]
# The current version takes one or more filenames on the command line.
# Each file has a temporary version written in the working directory with the ".mdw" extension added.
# After successful completion, the temporary file is copied over the source file and deleted.
# No file locking is performed! This script is very fast, so that isn't usually an issue, but be aware.
#
# You may place links to the TOC anywhere in your markdown, by including the following text: [Table Of Contents]
# The text  is configured by the "tocBegin" variable, set in CONFIGURATION below.
#
# By default, the TOC is generated at the very top of your file(s).
# Since this is probably not what you want--normally a TOC should appear under some introductory text--you can
# adjust the placement of the TOC by putting the following line where you want the TOC to appear:
# [//]: # (Place this line where you want the table of contents to start)
# (Not including the initial hashmark and space, of course).
# To save you from having to enter this, run the script without it the first time. It will insert the line at the top.
# Move the line using your editor to wherever you want it, and run the script again. It will move the table of contents to that spot.

### CONFIGURATION ###

# If you want to collapse one level of headings, set this to 1 (or higher).
# For example, if your document starts with an H1, and has everything else at H2, and you would rather pretend those H2s are H1s
# for HTML list nesting purposes, set this to 1.
my $collapseLevels = 1; # Default should be 0 for no collapsing

# If you don't want to include H1 headings in your TOC, set this to 2. If you don't want to include H1 or H2, set this to 3.
my $startWithLevel = 2; # Default should be 1 to include all heading levels starting at H1

# The markdown header placed at the start of your TOC--this is intended to be visible to users.
my $tocHeader = "\n# **TABLE OF CONTENTS**\n\n";

# The script will search for this line when deciding where to place the TOC.
# If it finds it, it will place the TOC after it; otherwise it will place it at the very top and insert this line above it.
# Don't change this unless you really understand the markdown syntax!
my $tocPlaceholder = "[//]: # (Place this line where you want the table of contents to start)\n";

# These are comments used by the script to find a previously generated TOC.
# They are hidden from people viewing the parsed version of the markdown.
# Don't change these unless you really understand the markdown syntax!
my $tocBegin = "[Table Of Contents]: <#user-content-table-of-contents> (TOC)\n";
my $tocEnd = "[//]: # (End of TOC)\n";

### END OF CONFIGURATION ###

use strict;
use warnings;
use File::Copy;

# Initializations and sanity checks
my @headers = ();
my $foundTOCPlaceHolder = 0;

if ($startWithLevel <= 0) {
    $startWithLevel = 1;
}

if ($collapseLevels < 0) {
    $collapseLevels = 0;
}

# Process command line files
foreach my $file (<*.md>) {
    # First pass
    open(my $fh, '<', $file) or die "Can't open $file: $!";
    my @lines = <$fh>;
    close $fh or die "Can't close $file: $!";

    @headers = ();

    foreach (@lines) {
    my $headerLevel = 0;
    if ($foundTOCPlaceHolder == 0 and $_ eq $tocPlaceholder) {
        $foundTOCPlaceHolder = 1;
    }
        if ($_ =~ /^######/) {
            $headerLevel = 6;
        }
        elsif ($_ =~ /^#####/) {
            $headerLevel = 5;
        }
        elsif ($_ =~ /^####/) {
            $headerLevel = 4;
        }
        elsif ($_ =~ /^###/) {
            $headerLevel = 3;
        }
        elsif ($_ =~ /^##/) {
            $headerLevel = 2;
        }
        elsif ($_ =~ /^#/) {
            $headerLevel = 1;
        }
        if ($headerLevel > 0) { # It's a heading, not a normal line
            if ($headerLevel >= $startWithLevel) { # Only include headers at or above the start with level
                push @headers, createLink($_, $headerLevel, $collapseLevels);
            }
        }
    }

    if (scalar(@headers) == 0) {
        next;
    }

# Second pass
    open(my $in, '<', $file) or die "Can't open $file' $!";
    open(my $out, '>', "$file.mdw") or die "Can't write $file.mdw: $!";

    my $traversingOldToc = 0;
    my $printedTOC = 0;
    while(<$in>) {
          # These comparisons all have to be done in a very specific order.
          # If we're already in an old TOC, all we want to do is eliminate it
          if ($traversingOldToc == 1) {
              # If this line is the last of an old TOC, we stop eliminating after this line
              if ($_ eq $tocEnd) {
                  $traversingOldToc = 0;
              }
              next; # Don't feed this line through to the output
          }
          # If a TOC placeholder was found in first pass, check for it and insert the TOC there when found
          # If not, then we insert the TOC at the top
          if ($printedTOC == 0) {
              if ($foundTOCPlaceHolder == 1) {
                  if ($_ eq $tocPlaceholder) { # Found it!
                      print $out $_;
                      print $out generateTOC();
                      $printedTOC = 1; # Make sure we don't print it again
                      next; # We already printed this line; process the next one
                  }
              } else { # Didn't find a placeholder; print the TOC at top of output
                  print $out $tocPlaceholder;
                  print $out generateTOC();
                  $printedTOC = 1;
          }
      }
          # If this line starts an old TOC, we get rid of it and flag further lines as old TOC lines
          if ($_ eq $tocBegin) {
              $traversingOldToc = 1;
              next; # Don't feed this line through to the output
          }
    print $out $_; # If the line hasn't been processed in some way, send it through to the output
    }

    close $in or die "Can't close $file: $!";
    close $out or die "Can't close $file.mdw: $!";

    move("$file.mdw", $file) or die "Can't rename $file.mdw to $file: $!";
}

# Returns a string containing a single HTML list item for the TOC
# @params:
# String containing a markdown header line
# Int indicating number of indentation (H1 is 1, H2 is 2, etc.)
# Int indicating how many levels of indentation to collapse (see the $collapseLevels CONFIGURATION variable)
sub createLink {
    my $currentLine = $_[0];
    my $indent = $_[1];
    my $collapseLevels = $_[2];

    my $text = substr($currentLine, $indent);

    $text =~ s/^\s+|\s+$//g; # Strip spaces from either end
    
    my $link = lc $text =~ s/[,\[\]\;:\/\?\"\'\*\+\.]+//gr; # Remove undesirable punctuation
    $link =~ s/ /-/g;

    if ($collapseLevels > 0) {
        $indent = $indent - $collapseLevels;
    }
    if ($indent < 0) { # In case the above went too far
        $indent = 0;
    }

    return " " x (($indent-1)*2) . "- " . "<a href=\"#user-content-$link\">$text</a>\n";
}

# Returns a string containing the HTML TOC
sub generateTOC {
    my $output = $tocBegin . $tocHeader;
    foreach(@headers) {
            $output = $output . $_;
    }

    $output = $output . "\n---\n\n";
    $output = $output . $tocEnd;
    return $output;
}
