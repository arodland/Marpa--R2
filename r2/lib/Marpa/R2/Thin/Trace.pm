# Copyright 2012 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

package Marpa::R2::Thin::Trace;

use 5.010;
use warnings;
use strict;

use vars qw($VERSION $STRING_VERSION);
$VERSION = '2.021_009';
$STRING_VERSION = $VERSION;
$VERSION = eval $VERSION;

sub new {
    my ($class, $grammar) = @_;
    my $self = bless {}, $class;
    $self->{g} = $grammar;
    $self->{symbol_by_name} = {};
    $self->{symbol_names} = {};
    return $self;
}

sub grammar {
   my ($self) = @_;
   return $self->{g};
}

sub symbol_by_name {
   my ($self, $name) = @_;
   return $self->{symbol_by_name}->{$name};
}

sub symbol_name {
   my ($self, $symbol_id) = @_;
   my $symbol_name = $self->{symbol_name}->[$symbol_id];
   $symbol_name = 'R' . $symbol_id if not defined $symbol_name;
   return $symbol_name;
}

sub symbol_name_set {
   my ($self, $name, $symbol_id) = @_;
   $self->{symbol_name}->[$symbol_id] = $name;
   $self->{symbol_by_name}->{$name} = $symbol_id;
   return $symbol_id;
}

sub symbol_new {
   my ($self, $name) = @_;
   return $self->symbol_name_set($name, $self->{g}->symbol_new());
}

sub dotted_rule {
    my ( $self, $rule_id, $dot_position ) = @_;
    my $grammar     = $self->{g};
    my $rule_length = $grammar->rule_length($rule_id);
    $dot_position = $rule_length if $dot_position < 0;
    my $lhs         = $self->symbol_name( $grammar->rule_lhs($rule_id) );
    my @rhs =
        map { $self->symbol_name( $grammar->rule_rhs( $rule_id, $_ ) ) }
        ( 0 .. $rule_length - 1 );
    $dot_position = 0 if $dot_position < 0;
    splice( @rhs, $dot_position, 0, q{.} );
    return join q{ }, $lhs, q{::=}, @rhs;
} ## end sub dotted_rule

sub progress_report {
    my ( $self, $recce, $ordinal ) = @_;
    my $result = q{};
    $ordinal //= $recce->latest_earley_set();
    $recce->progress_report_start($ordinal);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $origin ) = $recce->progress_item();
        last ITEM if not defined $rule_id; 
        $result
            .= q{@}
            . $origin . q{: }
            . $self->dotted_rule( $rule_id, $dot_position ) . "\n";
    } ## end ITEM: while (1)
    $recce->progress_report_finish();
    return $result;
} ## end sub progress_report

sub show_dotted_irl {
    my ( $self, $irl_id, $dot_position ) = @_;
    my $grammar_c = $self->{g};
    my $lhs_id    = $grammar_c->_marpa_g_irl_lhs($irl_id);
    my $irl_length = $grammar_c->_marpa_g_irl_length($irl_id);

    my $text = $self->isy_name($lhs_id) . q{ ->};

    if ( $dot_position < 0 ) {
        $dot_position = $irl_length;
    }

    my @rhs_names = ();
    for my $ix ( 0 .. $irl_length - 1 ) {
        my $rhs_isy_id = $grammar_c->_marpa_g_irl_rhs( $irl_id, $ix );
        my $rhs_isy_name = $self->isy_name($rhs_isy_id);
        push @rhs_names, $rhs_isy_name;
    }

    POSITION: for my $position ( 0 .. scalar @rhs_names ) {
        if ( $position == $dot_position ) {
            $text .= q{ .};
        }
        my $name = $rhs_names[$position];
        next POSITION if not defined $name;
        $text .= " $name";
    } ## end for my $position ( 0 .. scalar @rhs_names )

    return $text;

}

sub show_AHFA_item {
    my ( $self, $item_id ) = @_;
    my $grammar_c  = $self->{g};
    my $postdot_id = $grammar_c->_marpa_g_AHFA_item_postdot($item_id);
    my $sort_key   = $grammar_c->_marpa_g_AHFA_item_sort_key($item_id);
    my $text       = "AHFA item $item_id: ";
    my @properties = ();
    push @properties, "sort = $sort_key";

    if ( $postdot_id < 0 ) {
        push @properties, 'completion';
    }
    else {
        my $postdot_symbol_name = $self->isy_name($postdot_id);
        push @properties, qq{postdot = "$postdot_symbol_name"};
    }
    $text .= join q{; }, @properties;
    $text .= "\n" . ( q{ } x 4 );
    $text .= $self->show_brief_AHFA_item($item_id) . "\n";
    return $text;
} ## end sub show_AHFA_item

sub show_brief_AHFA_item {
    my ( $self, $item_id ) = @_;
    my $grammar_c  = $self->{g};
    my $postdot_id = $grammar_c->_marpa_g_AHFA_item_postdot($item_id);
    my $irl_id    = $grammar_c->_marpa_g_AHFA_item_irl($item_id);
    my $position   = $grammar_c->_marpa_g_AHFA_item_position($item_id);
    return $self->show_dotted_irl( $irl_id, $position );
} ## end sub Marpa::R2::show_brief_AHFA_item

sub show_AHFA {
    my ( $self, $verbose ) = @_;
    $verbose //= 1;    # legacy is to be verbose, so default to it
    my $grammar_c        = $self->{g};
    my $text             = q{};
    my $AHFA_state_count = $grammar_c->_marpa_g_AHFA_state_count();
    STATE:
    for ( my $state_id = 0; $state_id < $AHFA_state_count; $state_id++ ) {
        $text .= "* S$state_id:";
        defined $grammar_c->_marpa_g_AHFA_state_leo_lhs_symbol($state_id)
            and $text .= ' leo-c';
        $grammar_c->_marpa_g_AHFA_state_is_predict($state_id) and $text .= ' predict';
        $text .= "\n";
        my @items = ();
        for my $item_id ( $grammar_c->_marpa_g_AHFA_state_items($state_id) ) {
            push @items,
                [
                $grammar_c->_marpa_g_AHFA_item_irl($item_id),
                $grammar_c->_marpa_g_AHFA_item_postdot($item_id),
                $self->show_brief_AHFA_item( $item_id )
                ];
        } ## end for my $item_id ( $grammar_c->_marpa_g_AHFA_state_items($state_id...))
        $text .= join "\n", map { $_->[2] }
            sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @items;
        $text .= "\n";

        next STATE if not $verbose;

        my @raw_transitions = $grammar_c->_marpa_g_AHFA_state_transitions($state_id);
        my %transitions     = ();
        while ( my ( $isy_id, $to_state_id ) = splice @raw_transitions, 0,
            2 )
        {
            my $symbol_name = $self->isy_name($isy_id);
            $transitions{$symbol_name} = $to_state_id;
        } ## end while ( my ( $isy_id, $to_state_id ) = splice ...)
        for my $transition_symbol ( sort keys %transitions ) {
            $text .= ' <' . $transition_symbol . '> => ';
            my $to_state_id = $transitions{$transition_symbol};
            my @to_descs    = ("S$to_state_id");
            my $lhs_id = $grammar_c->_marpa_g_AHFA_state_leo_lhs_symbol($to_state_id);
            if ( defined $lhs_id ) {
                my $lhs_name = $self->isy_name($lhs_id);
                push @to_descs, "leo($lhs_name)";
            }
            my $empty_transition_state =
                $grammar_c->_marpa_g_AHFA_state_empty_transition($to_state_id);
            $empty_transition_state >= 0
                and push @to_descs, "S$empty_transition_state";
            $text .= ( join q{; }, sort @to_descs ) . "\n";
        } ## end for my $transition_symbol ( sort keys %transitions )

    } ## end for ( my $state_id = 0; $state_id < $AHFA_state_count...)
    return $text;
}

sub show_AHFA_items {
    my ($self) = @_;
    my $grammar_c = $self->{g};
    my $text      = q{};
    my $count     = $grammar_c->_marpa_g_AHFA_item_count();
    for my $AHFA_item_id ( 0 .. $count - 1 ) {
        $text .= $self->show_AHFA_item( $AHFA_item_id );
    }
    return $text;
}

sub isy_name {
    my ( $self, $id ) = @_;
    my $grammar_c = $self->{g};

    # The next is a little roundabout to prevent auto-instantiation
    my $name = '[ISY' . $id . ']';

    GEN_NAME: {

	if ($grammar_c->_marpa_g_isy_is_start($id)) {
	  my $source_id = $grammar_c->_marpa_g_source_xsy($id);
	  $name = $self->symbol_name($source_id);
	  $name .= q<[']>;
            last GEN_NAME;
	}

        my $lhs_xrl = $grammar_c->_marpa_g_isy_lhs_xrl($id);
        if ( defined $lhs_xrl and $grammar_c->rule_is_sequence($lhs_xrl) ) {
            my $original_lhs_id = $grammar_c->rule_lhs($lhs_xrl);
            $name = $self->symbol_name($original_lhs_id) . '[Seq]';
            last GEN_NAME;
        }

        my $xrl_offset = $grammar_c->_marpa_g_isy_xrl_offset($id);
        if ( $xrl_offset ) {
            my $original_lhs_id = $grammar_c->rule_lhs($lhs_xrl);
            $name =
                  $self->symbol_name($original_lhs_id) . '[R' 
                . $lhs_xrl . q{:}
                . $xrl_offset . ']';
            last GEN_NAME;
        } ## end if ( defined $xrl_offset )

        my $source_id = $grammar_c->_marpa_g_source_xsy($id);
        $name = $self->symbol_name($source_id);
        $name .= '[]' if $grammar_c->_marpa_g_isy_is_nulling($id);

    } ## end GEN_NAME:

    return $name;
}

1;
