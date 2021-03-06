=begin pod

=head1 ANTLR4::Actions::Perl6

C<ANTLR4::Actions::Perl6> generates a perl6 representation of an ANTLR4 AST.

=head1 Synopsis

    use ANTLR4::Actions::Perl6;
    use ANTLR4::Grammar;
    my $p = ANTLR4::Actions::Perl6.new;

    say $p.parsefile('ECMAScript.g4').perl6;

=head1 Documentation

The action in this file will return a completely unblessed abstract syntax
tree (AST) of the ANTLR4 grammar perl6 has been asked to parse. Other variants
may return an object or even the nearest perl6 equivalent grammar, but this
just returns a hash reference with nested array references.

=end pod

use v6;
use JSON::Tiny;
use ANTLR4::Grammar;
use ANTLR4::Actions::AST;

class ANTLR4::Actions::Perl6 {
	has ANTLR4::Grammar $g = ANTLR4::Grammar.new;
	has ANTLR4::Actions::AST $a = ANTLR4::Actions::AST.new;

	my class ANTLR4::Actions::Perl6::Shim {
		has $.ast;
		has $.perl6;
	}

	method alternation( $ast ) {
		my $terms = '';
		$terms = join( '|', map { self.term( $_ ) },
			       @( $ast.<content> ) )
			if @( $ast.<content> );
		qq{( $terms )};
	}

	method concatenation( $ast ) {
		my $json;
		my $terms = '';
		$terms = join( ' ', map { self.term( $_ ) },
			       @( $ast.<content> ) )
			if @( $ast.<content> );
		for <commands options label> -> $key {
			$json.{$key} = $ast.{$key} if $ast.{$key};
		}
		if $json {
			my $json-str = to-json( $json );
			$terms ~= qq{ #=$json-str};
		}
		qq{( $terms )};
	}

	method _modify( $ast, $term ) {
		my $temp = $term;
		$temp ~= $ast.<modifier> if $ast.<modifier>;
		$temp ~= '?' if $ast.<greedy>;
		$temp;
	}

	method terminal( $ast ) {
		my $term = '';
		$term ~= '!' if $ast.<complemented>;
		$term ~= qq{'$ast.<content>'};
		self._modify( $ast, $term );
	}

	method nonterminal( $ast ) {
		my $term = '';
		
		$term ~= '<';
		$term ~= '!' if $ast.<complemented>;
		$term ~= $ast.<content>;
		$term ~= '>';
		self._modify( $ast, $term );
	}

	method range( $ast ) {
		my $term = '';
		
		$term ~= '!' if $ast.<complemented>;
		$term ~= qq{'$ast.<content>[0]<from>'};
		$term ~= q{..};
		$term ~= qq{'$ast.<content>[0]<to>'};
		self._modify( $ast, $term );
	}

	method character-class( $ast ) {
		my $term = '';
		
		$term ~= '<';
		$term ~= '-' if $ast.<complemented>;
		$term ~= '[ ';
		$term ~= join( ' ', map {
			if /^(.)\-(.)/ {
				$_ = qq{$0 .. $1};
			}
			elsif /^\\u(....)/ {
				$_ = qq{\\x[$0]};
			}
			$_
		}, @( $ast.<content> ) );
		$term ~= ' ]>';
		self._modify( $ast, $term );
	}

	method capturing-group( $ast ) {
		my $term = '';
		
		$term ~= '!' if $ast.<complemented>;
		my $group = '';
		$group = join( ' ', map { self.term( $_ ) },
			       @( $ast.<content> ) )
			if @( $ast.<content> );
                $term ~= qq{( $group )};
		self._modify( $ast, $term );
	}

	method term( $ast ) {
		my $json;
		my $term = '';

		given $ast.<type> {
			when 'alternation' {
				$term = self.alternation( $ast );
			}
			when 'concatenation' {
				$term = self.concatenation( $ast );
			}
			when 'terminal' {
				$term = self.terminal( $ast );
			}
			when 'nonterminal' {
				$term = self.nonterminal( $ast );
			}
			when 'range' {
				$term = self.range( $ast );
			}
			when 'character class' {
				$term = self.character-class( $ast );
			}
			when 'capturing group' {
				$term = self.capturing-group( $ast );
			}
		}
		$term;
	}

	method rule( $ast ) {
		my $json;
		my $terms = '';

		$terms = join( ',', map { self.term( $_ ) },
                               @( $ast.<content> ) )
			if @( $ast.<content> );

		# Yes, probably a fancier way to do this, but it works.
		#
		for <attribute action returns throws locals options> -> $key {
			$json.{$key} = $ast.{$key} if $ast.{$key};
		}
		my $rule = qq{rule $ast.<name> { $terms }};
		if $json {
			my $json-str = to-json( $json );
			$rule ~= qq{ #=$json-str};
		}
		$rule;
	}

	method reconstruct( $ast ) {
		my $json;
		my $rules = '';

		$rules = join( ',', map { self.rule( $_ ) },
                               @( $ast.<content> ) )
			if @( $ast.<content> );

		# Yes, probably a fancier way to do this, but it works.
		#
		for <type options import tokens actions> -> $key {
			$json.{$key} = $ast.{$key} if $ast.{$key};
		}
		my $grammar = qq{grammar $ast.<name> { $rules }};
		if $json {
			my $json-str = to-json( $json );
			$grammar ~= qq{ #=$json-str};
		}
		$grammar;
	}

	method parse( $str ) {
		my $ast = $!g.parse( $str, :actions($!a) ).ast;
		ANTLR4::Actions::Perl6::Shim.new(
			ast => $ast,
			perl6 => self.reconstruct( $ast )
		)
	}
}

# vim: ft=perl6
