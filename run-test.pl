#!/usr/bin/perl -w

use IO::Socket;

$USAGE = "Usage: $0 host[:port] [-d] testfile1, testfile2, ...\n";
$USERAGENT = "HTTP test utility";

$debug = 0;

$count = 0;

$line_terminator = "\r\n";

sub perform_test {
    my $filename = shift(@_);

    if (!open(FILE, $filename)) {
        print("Could not open file $filename.\n");
        return;
    }

    $socket = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $server, PeerPort => $port, Timeout => 10);

    if(!$socket) {
        # this is treated as a serious problem and we
        # die if we cannot connect
        die("Could not connect to $server:$port");
    }

    $socket->autoflush(1);

    $mode = 1;

    $send_host_header = 1;
    $send_useragent_header = 1;
    $send_connection_header = 1;
    
    @rules = ();

    LINE: while(<FILE>) {

        $send_line = 1;
    
        if ($mode == 1) {

            # discard comments at the beginning of the file
            if (/^#/) {
                chomp();
            
                # is there a rule on this line
                if (/^#\s*@\s*(\S+)(\s+(\S+)\s+(\S+))?/) {
                    push(@rules, $_);
                }

                next LINE;
            }

            $mode = 2;
    
            # execution flow continues as
            # mode is 2 now
        }        

        if ($mode == 2) {

            # check for the "Host" header
            if (/^(Host: )(.*)$/i) {
                $send_host_header = 0;
                if ($2 eq "-") {
                    $send_line = 0;
                }
            }

            # check for the "User-Agent" header
            if (/^(User-Agent: )(.*)$/i) {
                $send_useragent_header = 0;
                if ($2 eq "-") {
                    $send_line = 0;
                }
            }

            # check for the "Connection" header
            if (/^(Connection: )(.*)$/i) {
                $send_connection_header = 0;
                if ($2 eq "-") {
                    $send_line = 0;
                }
            }

            if (/^$/) {
                # empty line detected, the body follows
                $mode = 3;

                # send additional headers
                if ($send_host_header) {
                    print $socket "Host: $server:$port" . $line_terminator;
                    if ($debug) { print "> Host: $server:$port" . $line_terminator; }
                }

                if ($send_useragent_header) {
                    print $socket "User-Agent: $USERAGENT" . $line_terminator;
                    if ($debug) { print "> User-Agent: $USERAGENT" . $line_terminator; }
                }

                if ($send_connection_header) {
                    print $socket "Connection: Close" . $line_terminator;
                    if ($debug) { print "> Connection: Close" . $line_terminator; }
                }
            }

            if ($send_line) {
                $_ =~ s/[\r\n]//g;
                print $socket $_ . $line_terminator;
                if ($debug) { print "> $_" . $line_terminator; }
            }

            next LINE;
        }

        if ($mode == 3) {
            print $socket $_;
            if ($debug) { print "> $_"; }
        }   
    }

    close(FILE);

    $response_status = 0;
    $headers = 1;
    $response_body = "";
    $lines_seen = 0;
    while (<$socket>) {
        $lines_seen++;
        if ($debug) { print "< $_"; }
        
        if ($headers) {        
            if ($lines_seen == 1) {
                if (($response_status == 0) && (/^HTTP\/[0-9]\.[0-9] ([0-9]+).+$/)) {
                    $response_status = $1;
                } else {
                    # Assume HTTP/0.9 response
                    $headers = 0;
                    $response_body = $_;
                }
            }
            
            if (/^\s*$/) {
                $headers = 0;
            }
        } else {
            $response_body = $response_body . $_;
        }
    }
    
    # print "Response: $response\n";
    $result = "Unknown";

    # Run through the rules now    
    foreach $rule (@rules) {
        #print "Rule: $rule\n";
        
        if ($rule =~ /^#\s*@\s*(\S+)(\s+(\S+)\s+(\S+))?/) {
            $rule_result = $1;
            $variable_name = $3;
            $condition = $4;
            
            if ($variable_name) {
                # Test rule

                # Get the first character of the regular
                # expression, to check for negation                
                $c = substr($condition, 0, 1);
                if ($c eq "!") {
                    $condition = substr($condition, 1, length($condition) - 1);
                }
                
                if ($variable_name eq "RESPONSE_STATUS") {
                    if ($c ne "!") {
                        if ($response_status =~ /$condition/) {
                            $result = $rule_result;
                            last;
                        }
                    } else {
                        if ($response_status !~ /$condition/) {
                            $result = $rule_result;
                            last;
                        }
                    }
                } elsif ($variable_name eq "RESPONSE_BODY") {
                    if ($c ne "!") {
                        if ($response_body =~ /$condition/) {
                            $result = $rule_result;
                            last;
                        }
                    } else {
                        if ($response_body !~ /$condition/) {
                            $result = $rule_result;
                            last;
                        }
                    }
                } else {
                    die("Invalid variable name: $variable_name");
                }
            } else {
                # No condition
                $result = $rule_result;
                last;
            }
        }
    }
    
    if ($debug) {
        print "\n";
    }

    print "$filename: $result\n";
}


# -- main -------------------------------------------

if(!@ARGV) {
    print $USAGE;
    exit;
}

if ($#ARGV < 1) {
    print $USAGE;
    exit;
}

$_ = shift(@ARGV);

if (/(.+):(.+)/) {
    $server = $1;
    $port = $2;
} else {
    $server = $_;
    $port = 80;
}

foreach $filename (@ARGV) {
    if ($filename =~ /^-d$/) {
        $debug = 1;
    } else {
        perform_test($filename);
        $count++;
    }
}

if ($count == 0) {
    print $USAGE;
}

