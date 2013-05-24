#!/usr/bin/perl -w

use IO::Socket;

$USAGE = "Usage: $0 host[:port] [-d] [-ssl] [-p proxyhost[:proxyport]] [-b path] testfile1, testfile2, ...\n";
$USERAGENT = "HTTP test utility";

$debug = 0;

$count = 0;

$all_payloads = ();

$PAYLOAD = "";
$PAYLOAD_ENCODED = "";

$line_terminator = "\r\n";

$encode_payloads = 0;

my $SSL = 0;
my $PROXY_host = "";
my $PROXY_port = 0;

my $BASEPATH = "";


sub trim {
    @_ = $_ if not @_ and defined wantarray;
    @_ = @_ if defined wantarray;
    for (@_ ? @_ : $_) { s/^\s+//, s/\s+$// }
    return wantarray ? @_ : $_[0] if defined wantarray;
}

sub urlencode {
    my $s = shift;
    $s =~ s/ /+/g;
    $s =~ s/([^A-Za-z0-9\+-])/sprintf("%%%02X", ord($1))/seg;
    return $s;
}

sub urldecode {
    my $s = shift;
    $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $s =~ s/\+/ /g;
    return $s;
}

sub perform_test {
    my $filename = shift(@_);

    if (!open(FILE, $filename)) {
        print("Could not open file $filename.\n");
        return;
    }

    my $socket = undef;
    if ($PROXY_host && $PROXY_port) {
        $socket = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $PROXY_host, PeerPort => $PROXY_port, Timeout => 10);
        if ($debug) { print "Connected to proxy $PROXY_host:$PROXY_port" . $line_terminator }
    } else {
        if ($SSL) {
            require IO::Socket::SSL;
            $socket = IO::Socket::SSL->new(Proto => 'tcp', PeerAddr => $server, PeerPort => $port, Timeout => 10);
        } else {
            $socket = IO::Socket::INET->new(Proto => 'tcp', PeerAddr => $server, PeerPort => $port, Timeout => 10);
        }
    }

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
                # Remove line terminator
                $_ =~ s/[\r\n]//g;
                
                # Insert attack payload
                $_ =~ s/\$PAYLOAD/$PAYLOAD_ENCODED/;

                if ($BASEPATH) {
                    $_ =~ s# /# $BASEPATH#;
                }

                if ($PROXY_host && $PROXY_port) {
                    $_ =~ s# /# http://$server:$port/#;
                }
                
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

    if (!($PAYLOAD eq "")) {
        print "$filename ($PAYLOAD): $result\n";
    } else {
        print "$filename: $result\n";
    }
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
    if ((defined $payload_file) && ($payload_file eq "next")) {
        $payload_file = $filename;
        
        if (!open(PFILE, $payload_file)) {
            print("Could not open file $payload_file.\n");
            return;
        }
        
        $all_payloads = ();
        
        PLINE: while(<PFILE>) {
            trim;
            
            # Ignore comments
            if (/^#/) {
                next PLINE;
            }
            
            # Ignore empty lines
            if (/^$/) {
                next PLINE;
            }
            
            chomp($_);
            push(@all_payloads, $_);
        }
        
        close(PFILE);
    }
    elsif ((defined $proxy) && ($proxy eq "proxy")) {
        if ($filename =~ /(.+):(.+)/) {
            $PROXY_host = $1;
            $PROXY_port = $2;
        } else {
            $PROXY_host = $_;
            $PROXY_port = 80;
        }
        
        $proxy = undef;
    }
    elsif ((defined $path) && ($path eq "basepath")) {
        $BASEPATH = $filename;
        $BASEPATH =~ s#^/*(.*?)/*$#/$1/#;

        $path = undef;
    }
    elsif ($filename =~ /^-d$/) {
        $debug = 1;
    }
    elsif ($filename =~ /^-e$/) {
        $encode_payloads = 1;
    }
    elsif ($filename =~ /^-x$/) {
        $payload_file = "next";
    }
    elsif ($filename =~ /^-s(?:sl)?$/) {
        $SSL = 1;
    }
    elsif ($filename =~ /^-p$/) {
        $proxy = "proxy";
    }
    elsif ($filename =~ /^-b$/) {
        $path = "basepath";
    }
    else {
        if (defined $payload_file) {
            foreach $PAYLOAD (@all_payloads) {
                if ($encode_payloads) {
                    $PAYLOAD_ENCODED = urldecode($PAYLOAD);
                    $PAYLOAD_ENCODED = urlencode($PAYLOAD_ENCODED);
                } else {
                    $PAYLOAD_ENCODED = $PAYLOAD;
                    $PAYLOAD = urldecode($PAYLOAD_ENCODED);
                }
                
                perform_test($filename);
                
                $count++;
            }
        } else {
            perform_test($filename);
            $count++;
        }
    }
}

if ($count == 0) {
    print $USAGE;
}

