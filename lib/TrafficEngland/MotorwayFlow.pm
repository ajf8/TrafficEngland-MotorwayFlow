package TrafficEngland::MotorwayFlow;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

use WWW::Mechanize;
use HTML::TreeBuilder::XPath;
use HTML::TokeParser;
use Carp;

use constant MOTORWAY_FLOW_PAGE => "http://www.trafficengland.com/motorwayflow.aspx";
use constant MAIN_FORM_NUMBER => 1;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use TrafficEngland::MotorwayFlow ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;

    my $mech = WWW::Mechanize->new();
    $mech->agent_alias("Windows IE 6");
    $self->{'mech'} = $mech;
    
    $self->{'decode_left'} = 1;
    $self->{'decode_right'} = 1;
    $self->{'min_level'} = 0;
    $self->{'compact'} = 0;

    return $self;
}

sub compact
{
  my ($self, $value) = @_;
  $self->{'compact'} = $value if defined($value);
  return $self->{'compact'};
}

sub minimum_level
{
  my ($self, $value) = @_;
  $self->{'min_level'} = $value if defined($value);
  return $self->{'min_level'};
}

sub decode_left
{
  my ($self, $value) = @_;
  $self->{'decode_left'} = $value if defined($value);
  return $self->{'decode_left'};
}

sub decode_right
{
  my ($self, $value) = @_;
  $self->{'decode_right'} = $value if defined($value);
  return $self->{'decode_right'};
}

sub mech
{
  my $self = shift;
  return $self->{'mech'};
}

sub get_flow_page
{
  my $self = shift;
  $self->mech()->get(MOTORWAY_FLOW_PAGE);
}

sub motorway_list
{
  my $self = shift;
  my $picker = $self->motorway_picker();
  my @values = $picker->possible_values();
  my %select;
  my $i = 0;
  for my $name ($picker->value_names())
  {
    if ((my $value = $values[$i++]) >= 0)
    {
      $select{$name} = int($value);
    }
  }
  return \%select;
}

sub main_form
{
  my $self = shift;
  return $self->mech()->form_number(MAIN_FORM_NUMBER);
}

sub motorway_picker
{
  my $self = shift;
  return $self->main_form()->find_input("#ctl00_ContentPlaceHolder1_ctl00_pickMotorway");
}

sub start_junction_picker
{
  my $self = shift;
  return $self->main_form()->find_input("#ctl00_ContentPlaceHolder1_ctl00_pickStartJunction");
}

sub end_junction_picker
{
  my $self = shift;
  return $self->main_form()->find_input("#ctl00_ContentPlaceHolder1_ctl00_pickEndJunction");
}

sub submit_form
{
  my $self = shift;
  $self->mech()->submit_form(form_number => MAIN_FORM_NUMBER);
}

sub get_junctions
{
  my ($self) = @_;
  my $picker = $self->start_junction_picker();
  my @values = $picker->possible_values();
  my $i = 0;
  my @junctions;
  for my $key ($picker->value_names())
  {
    if ((my $value = $values[$i++]) > 0)
    {
      my %junction;
      $junction{'name'} = $key;
      $junction{'value'} = $value;
      push(@junctions, \%junction);
    }
  }
  return \@junctions;
}

sub set_motorway_by_id
{
  my ($self, $mway) = @_;
  $self->motorway_picker()->value($mway);
  $self->submit_form();
}

sub set_motorway_by_name
{
  my ($self, $mway) = @_;
  my $motorway_list = $self->motorway_list();
  $self->set_motorway_by_id($motorway_list->{uc($mway)});
}

sub search
{
  my $self = shift;
  my $searchButton = $self->main_form()->find_input("#ctl00_ContentPlaceHolder1_ctl00_btnSearch");
  $self->mech()->click_button(input => $searchButton);
}

sub decode
{
  my $self = shift;
  my $tree= HTML::TreeBuilder::XPath->new;
  my %output;

  #$tree->parse_file("m25.html");
  $tree->parse_content($self->mech()->content());

  $output{'leftTitle'} = $tree->findvalue('//span[@id = \'ctl00_ContentPlaceHolder1_ctl00_mtfSchematicContainer1_ctl00_lblADirection\']');
  $output{'rightTitle'} = $tree->findvalue('//span[@id = \'ctl00_ContentPlaceHolder1_ctl00_mtfSchematicContainer1_ctl00_lblBDirection\']');
  $output{'roadName'} = $tree->findvalue('//span[@id = \'ctl00_ContentPlaceHolder1_ctl00_mtfSchematicContainer1_ctl00_lblRoadName\']');

  my @junctionNames = $tree->findnodes_as_strings('//a[contains(@id, \'lnkLhsDescription\')]');
  my @junctionIds = $tree->findnodes_as_strings('//a[contains(@id, \'lnkJunctionName\')]');
  my @stretchTables = $tree->findnodes('//table[@class = \'junction_stretch_table\']');

  $output{'junctionIds'} = \@junctionIds;
  $output{'junctionNames'} = \@junctionNames;

  my @leftJunctions;
  my @rightJunctions;
  my $i = 0;
  for (my $i = 0; $i < @junctionNames; $i++)
  {
    my $table;
    last unless defined($table = $stretchTables[$i]);
    if ($self->decode_left())
    {
      my @lhs = $table->findnodes('./tr/td[@class = \'junction_stretch_road_items_cell_left\']');
      $self->decode_junction_stretch($lhs[0], \@leftJunctions, $junctionNames[$i], $i);
    }
    if ($self->decode_right())
    {
      my @rhs = $table->findnodes('./tr/td[@class = \'junction_stretch_road_items_cell_right\']');
      $self->decode_junction_stretch($rhs[0], \@rightJunctions, $junctionNames[$i], $i);
    }
  }
  
  $output{'leftJunctions'} = \@leftJunctions;
  $output{'rightJunctions'} = \@rightJunctions;

  $tree->delete();
  return \%output;
}

sub decode_event_items
{
  my ($self, @nodeSet) = @_;
  my @items;
  for my $item (@nodeSet)
  {
    push(@items, $self->decode_event_item($item));
  }
  return \@items;
}

sub decode_event_item
{
  my ($self, $item) = @_;
  my %output;
  $output{'description'} = $item->findvalue('.//span[contains(@id, \'lblDescription\')]');
  if (defined(my $delay = $item->findvalue('.//span[contains(@id, \'lblDelay\')]')))
  {
    $output{'delay'} = $delay;
  }
  return \%output;
}

sub decode_weather_item
{
  my ($self, $item) = @_;
  my %output;
  my $title = $item->findnodes_as_string('.//span/div[@id = \'title\']');
  my $tp = HTML::TokeParser->new( \$title );
  my $i = 0;
  while (my $t = $tp->get_token())
  {
    if ($t->[0] eq 'T')
    {
      if ($i++ > 0)
      {
        $output{'title'} = $t->[1];
        last;
      }
      else
      {
        $output{'location'} = $t->[1];
      }
    }
  }
  return \%output;
}

sub decode_status
{
  my ($self, $stretch) = @_;
  if ($stretch->findvalue('./@style') =~ m/solid #(.*);/)
  {
    my $color = $1;
    if ($color eq 'FF6600')
    {
      return 1;
    }
    elsif ($color eq 'FF0000')
    {
      return 2;
    }
  }

  return 0;
}

sub decode_junction_stretch
{
  my ($self, $stretch, $toArrayRef, $title, $number) = @_;

  my $status = $self->decode_status($stretch);
  if ($status < $self->minimum_level())
  {
    return;
  }
  
  my %output;

  my @matrixMsgs;
  for my $matrixMsg ($stretch->findnodes_as_strings('.//span[contains(@id, \'lblMessage\')]'))
  {
    $matrixMsg =~ s/^\s+//;
    $matrixMsg =~ s/\s+$//;
    push(@matrixMsgs, $matrixMsg);
  }

  my @cameras;
  for my $cam ($stretch->findnodes_as_strings('.//a[contains(@id, \'lnkCameraHyperlink\')]/@href'))
  {
    push(@cameras, int($1)) if ($cam =~ m/cctvpublicaccess\/html\/(\d+).html/);
  }

  my @matrixRows;
  for my $matrixItem ($stretch->findnodes('.//table[@class = \'matrixItem\']'))
  {
    my @matrixLanes;
    for my $item ($matrixItem->findnodes_as_strings('.//div[@class = \'matrixDisplay\']/img/@src'))
    {
      push(@matrixLanes, $1) if ($item =~ m/motorwayflow\/(.*).gif$/);
    }
    push(@matrixRows, \@matrixLanes);
  }

  my @weather;
  for my $weatherItem ($stretch->findnodes('.//table[@class = \'weatherItem\']'))
  {
    push (@weather, $self->decode_weather_item($weatherItem));
  }
  
  unless ($self->compact())
  {
    $output{'title'} = $title;
  }
  $output{'incidents'} = $self->decode_event_items($stretch->findnodes('.//table[contains(@id, \'Incident\')]'));
  $output{'roadworks'} = $self->decode_event_items($stretch->findnodes('.//table[@class = \'roadWorksItem\']'));
  if ($stretch->findvalue('.//span[contains(@id, \'lblSpeed\')]') =~ m/(\d+) mph/)
  {
    $output{'averageSpeed'} = int($1);
  }
  else
  {
    $output{'averageSpeed'} = -1;
  }
  $output{'weather'} = \@weather;
  $output{'matrixMsgs'} = \@matrixMsgs;
  $output{'matrixRows'} = \@matrixRows;
  $output{'cameras'} = \@cameras;
  $output{'status'} = $status;

  push(@$toArrayRef, \%output);

  return \%output;
}

sub set_start_junction_by_id
{
  my ($self, $jid) = @_;
  $self->start_junction_picker()->value($jid);
}

sub set_end_junction_by_id
{
  my ($self, $jid) = @_;
  $self->end_junction_picker()->value($jid);
}

sub set_junction_by_name
{
  my ($self, $picker, $jname) = @_;
  my $junctions = $self->get_junctions();
  croak unless defined($junctions->{$jname});
  $picker->value($junctions->{$jname});
}

sub set_start_junction_by_name
{
  my ($self, $jname) = @_;
  $self->set_junction_by_name($self->start_junction_picker(), $jname);
}

sub set_end_junction_by_name
{
  my ($self, $jname) = @_;
  $self->set_junction_by_name($self->end_junction_picker(), $jname);
}

sub whole_motorway
{
  my ($self, $mway) = @_;
  my @values = $self->start_junction_picker()->possible_values();
  croak unless (@values >= 3);
  $self->set_start_junction_by_id($values[1]);
  $self->set_end_junction_by_id($values[@values-1]);
}

sub set_all_info
{
  my $self = shift;
  $self->set_info();
}

sub set_info
{
  my ($self, @chosenInputs) = @_;
  INPUTLOOP: for my $input ($self->main_form()->inputs())
  {
    if ($input->type() eq 'checkbox' && $input->id() =~ m/^ctl00_ContentPlaceHolder1_ctl00_chk(.*)/)
    {
      my $inputId = $1;
      if (!@chosenInputs)
      {
        $input->check();
      }
      else
      {
        for my $cInput (@chosenInputs)
        {
          if ($cInput eq $inputId)
          {
            $input->check();
            next INPUTLOOP;
          }
        }
        $input->check(undef);
      }
    }
  }
}

sub _select_to_hash
{
}

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TrafficEngland::MotorwayFlow - Perl extension for blah blah blah

=head1 SYNOPSIS

  use TrafficEngland::MotorwayFlow;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for TrafficEngland::MotorwayFlow, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Alan F, E<lt>alan@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Alan Fitton

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
