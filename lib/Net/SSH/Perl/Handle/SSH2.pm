package Net::SSH::Perl::Handle::SSH2;
use strict;

use Net::SSH::Perl::Buffer qw( SSH2 );
use Net::SSH::Perl::Constants qw( :channels );

use Carp qw( croak );
use Tie::Handle;
use base qw( Tie::Handle );

sub TIEHANDLE {
    my $class = shift;
    my($mode, $channel, $r_exit) = @_;
    my $read = $mode =~ /^[rR]/;
    my $handle = bless { channel => $channel, exit => $r_exit }, $class;
    if ($read) {
        my $incoming = $handle->{incoming} = Net::SSH::Perl::Buffer->new;
        $channel->register_handler("_output_buffer", sub {
            my($channel, $buffer) = @_;
            $incoming->append($buffer->bytes);
            $channel->{ssh}->break_client_loop;
        });
    }
    $handle;
}

sub READ {
    my $h = shift;
    my $buf = $h->{incoming};
    while (!$buf->length) {
        $h->{channel}{ssh}->client_loop;
        croak "Connection closed" unless $buf->length;
    }
    $_[0] = $buf->bytes;
    $buf->empty;
    length($_[0]);
}

sub WRITE {
    my $h = shift;
    my($data) = @_;
    $h->{channel}->send_data($data);
    length($data);
}

sub EOF { defined ${$_[0]->{exit}} ? 1 : 0 }

sub CLOSE {
    my $h = shift;
    unless ($h->{incoming}) {
        my $c = $h->{channel};
        my $ssh = $c->{ssh};
        $c->{istate} = CHAN_INPUT_WAIT_DRAIN;
        $c->send_eof;
        $c->{istate} = CHAN_INPUT_CLOSED;
        $ssh->client_loop;
    }
}

=pod

sub DESTROY {
    my $h = shift;
    unless ($h->{incoming}) {
        my $c = $h->{channel};
        my $ssh = $c->{ssh};
        $c->{istate} = CHAN_INPUT_WAIT_DRAIN;
        $c->send_eof;
        $c->{istate} = CHAN_INPUT_CLOSED;
        $ssh->client_loop;
    }
}

=cut

1;