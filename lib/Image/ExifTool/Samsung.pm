#------------------------------------------------------------------------------
# File:         Samsung.pm
#
# Description:  Samsung EXIF maker notes tags
#
# Revisions:    2010/03/01 - P. Harvey Created
#
# References:   1) Tae-Sun Park private communication
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#------------------------------------------------------------------------------

package Image::ExifTool::Samsung;

use strict;
use vars qw($VERSION %samsungLensTypes);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.09';

sub WriteSTMN($$$);
sub ProcessINFO($$$);

%samsungLensTypes = (
    0 => 'Built-in', #PH (EX1, WB2000)
    1 => 'Samsung 30mm F2 Pancake',
    2 => 'Samsung Zoom 18-55mm F3.5-5.6 OIS',
    3 => 'Samsung Zoom 50-200mm F4-5.6 ED OIS',
    # what about the non-OIS version of the 18-55,
    # which was supposed to be available before the 20-50?
    4 => 'Samsung 20-50mm F3.5-5.6 Compact Zoom', #PH
    5 => 'Samsung 20mm F2.8 Pancake', #PH (guess)
);

# range of values for Formats used in encrypted information
my %formatMinMax = (
    int16u => [ 0, 65535 ],
    int32u => [ 0, 4294967295 ],
    int16s => [ -32768, 32767 ],
    int32s => [ -2147483648, 2147483647 ],
);

# Samsung "STMN" maker notes (ref PH)
%Image::ExifTool::Samsung::Type1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&WriteSTMN,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    IS_OFFSET => [ 2 ],   # tag 2 is 'IsOffset'
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Tags found in the binary "STMN" format maker notes written by a number of
        Samsung models.
    },
    0 => {
        Name => 'MakerNoteVersion',
        Format => 'undef[8]',
    },
    2 => {
        Name => 'PreviewImageStart',
        OffsetPair => 3,  # associated byte count tagID
        DataTag => 'PreviewImage',
        IsOffset => 3,
        Protected => 2,
    },
    3 => {
        Name => 'PreviewImageLength',
        OffsetPair => 2,   # point to associated offset
        DataTag => 'PreviewImage',
        Protected => 2,
    },
);

# Samsung maker notes (ref PH)
%Image::ExifTool::Samsung::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags found in the EXIF-format maker notes of newer Samsung models.',
    0x0001 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0021 => { #1
        Name => 'PictureWizard',
        Writable => 'int16u',
        Count => 5,
        PrintConv => q{
            my @a = split ' ', $val;
            return $val unless @a == 5;
            sprintf("Mode: %d, Col: %d, Sat: %d, Sha: %d, Con: %d",
                    $a[0], $a[1], $a[2]-4, $a[3]-4, $a[4]-4);
        },
        PrintConvInv => q{
            my @a = ($val =~ /[+-]?\d+/g);
            return $val unless @a >= 5;
            sprintf("%d %d %d %d %d", $a[0], $a[1], $a[2]+4, $a[3]+4, $a[4]+4);
        },
    },
    # 0x0023 - string: "0123456789" (PH)
    0x0030 => { #1 (NX100 with GPS)
        Name => 'LocalLocationName',
        Writable => 'string',
        Format => 'undef',
        # this contains 2 place names (in Korean if in Korea), separated by a null+space
        # - terminate at double-null and replace nulls with newlines
        ValueConv => '$val=~s/\0\0.*//; $val=~s/\0 */\n/g; $val',
        ValueConvInv => '$val=~s/(\x0d\x0a|\x0d|\x0a)/\0 /g; $val . "\0\0"'
    },
    0x0031 => { #1 (NX100 with GPS)
        Name => 'LocationName',
        Writable => 'string',
    },
    0x0035 => {
        Name => 'PreviewIFD',
        Condition => '$$self{TIFF_TYPE} eq "SRW"', # (not an IFD in JPEG images)
        Groups => { 1 => 'PreviewIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewIFD',
            ByteOrder => 'Unknown',
            Start => '$val',
        },
    },
    0x0043 => { #1 (NC)
        Name => 'CameraTemperature',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        # (DPreview samples all 0.2 C --> pre-production model)
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    # 0x00a0 - undef[8192]: white balance information (ref 1):
    #   At byte 5788, the WBAdjust: "Adjust\0\X\0\Y\0\Z\xee\xea\xce\xab", where
    #   Y = BA adjust (0=Blue7, 7=0, 14=Amber7), Z = MG (0=Magenta7, 7=0, 14=Green7)
#
# the following tags found only in SRW images
#
    # 0xa000 - rational64u: 1 or 1.1 (ref PH)
    0xa001 => { #1
        Name => 'FirmwareName',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    # 0xa002 - string[30]: '0' or 'DY049P000000' (ref PH)
    0xa003 => { #1 (SRW images only)
        Name => 'LensType',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => \%samsungLensTypes,
    },
    0xa004 => { #1
        Name => 'LensFirmware',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    # 0xa005 - string[30]: constant for a given lens? Not the printed serial number (ref 1)
    0xa010 => { #1
        Name => 'SensorAreas',
        Groups => { 2 => 'Camera' },
        Notes => 'full and valid sensor areas',
        Writable => 'int32u',
        Count => 8,
    },
    0xa011 => { #1
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
        },
    },
    0xa012 => { #1
        Name => 'SmartRange',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xa013 => { #1
        Name => 'ExposureCompensation',
        Writable => 'rational64s',
    },
    0xa014 => { #1
        Name => 'ISO',
        Writable => 'int32u',
    },
    0xa018 => { #1
        Name => 'ExposureTime',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0xa019 => { #1
        Name => 'FNumber',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0xa01a => { #1
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
        Format => 'int32u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0xa020 => { #1
        Name => 'EncryptionKey',
        Writable => 'int32u',
        Count => 11,
        Protected => 1,
        DataMember => 'EncryptionKey',
        RawConv => '$$self{EncryptionKey} = [ split(" ",$val) ]; $val',
        Notes => 'key used to decrypt the tags below',
        # value is "305 72 737 456 282 307 519 724 13 505 193"
    },
    0xa021 => { #1
        Name => 'WB_RGGBLevelsUncorrected',
        Writable => 'int32u',
        Count => 4,
        Notes => 'these tags not corrected for WB_RGGBLevelsBlack',
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa022 => { #1
        Name => 'WB_RGGBLevelsAuto',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-4)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,4)',
    },
    0xa023 => { #1
        Name => 'WB_RGGBLevelsIlluminator1',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-8)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,8)',
    },
    0xa024 => { #1
        Name => 'WB_RGGBLevelsIlluminator2',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-1)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,1)',
    },
    #this doesn't seem correct
    #0xa025 => { #PH/1
    #    Name => 'ColorTemperatureAuto',
    #    Writable => 'int32u',
    #    RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,6)',
    #    RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-6)',
    #},
    0xa028 => { #2/PH
        Name => 'WB_RGGBLevelsBlack',
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa030 => { #1
        Name => 'ColorMatrix',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa031 => { #1
        Name => 'ColorMatrixSRGB',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa032 => { #1
        Name => 'ColorMatrixAdobeRGB',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa033 => { #1
        Name => 'Samsung_Type2_0xa033',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa034 => { #1
        Name => 'Samsung_Type2_0xa034',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,4)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-4)',
    },
    0xa035 => { #1
        Name => 'Samsung_Type2_0xa035',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32u',
        Count => 2,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa036 => { #1
        Name => 'Samsung_Type2_0xa036',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32u',
        Count => 2,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-2)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,2)',
    },
    0xa040 => { #1
        Name => 'ToneCurve1',
        Writable =>  'int32u',
        Count => 23,
        Notes => q{
            first value gives the number of tone curve entries.  This is followed by an
            array of X coordinates then an array of Y coordinates
        },
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa041 => { #1
        Name => 'ToneCurve2',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa042 => { #1
        Name => 'ToneCurve3',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa043 => { #1
        Name => 'ToneCurve4',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa048 => { #1
        Name => 'Samsung_Type2_0xa048',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 12,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa050 => { #1 (vignette curve?)
        Name => 'Samsung_Type2_0xa050',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa051 => { #1
        Name => 'Samsung_Type2_0xa051',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int16u',
        Count => 22,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",-7,-3)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,7,3)',
    },
    0xa052 => { #1 (vignette curve?)
        Name => 'Samsung_Type2_0xa052',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa053 => { #1
        Name => 'Samsung_Type2_0xa053',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa054 => { #1
        Name => 'Samsung_Type2_0xa054',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa055 => { #1
        Name => 'Samsung_Type2_0xa055',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,8)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-8)',
    },
    0xa056 => { #1
        Name => 'Samsung_Type2_0xa056',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,5)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-5)',
    },
    0xa057 => { #1
        Name => 'Samsung_Type2_0xa057',
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,2)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-2)',
    },
);

# INFO tags in Samsung MP4 videos (ref PH)
%Image::ExifTool::Samsung::INFO = (
    PROCESS_PROC => \&ProcessINFO,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => q{
        This information is found in MP4 videos from Samsung models such as the
        SMX-C20N.
    },
    EFCT => 'Effect', # (guess)
    QLTY => 'Quality',
    # MDEL - value: 0
    # ASPT - value: 1, 2
);

# Samsung MP4 TAGS information (PH - from WP10 sample)
# --> very similar to Sanyo MP4 information
%Image::ExifTool::Samsung::MP4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in Samsung MP4 videos from models such as the
        WP10.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[16]',
    },
    0x2e => { # (NC)
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x32 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x3a => { # (NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
    },
    0x6a => {
        Name => 'ISO',
        Format => 'int32u',
    },
    0x7d => {
        Name => 'Software',
        Format => 'string[32]',
        # (these tags are not at a constant offset for Sanyo videos,
        #  so just to be safe use this to validate subsequent tags)
        RawConv => q{
            $val =~ /^SAMSUNG/ or return undef;
            $$self{SamsungMP4} = 1;
            return $val;
        },
    },
    0xf8 => {
        Name => 'ThumbnailWidth',
        Condition => '$$self{SamsungMP4}',
        Format => 'int32u',
    },
    0xfc => {
        Name => 'ThumbnailHeight',
        Condition => '$$self{SamsungMP4}',
        Format => 'int32u',
    },
    0x100 => {
        Name => 'ThumbnailLength',
        Condition => '$$self{SamsungMP4}',
        Format => 'int32u',
    },
    0x104 => {
        Name => 'ThumbnailOffset',
        Condition => '$$self{SamsungMP4}',
        IsOffset => 1,
        Format => 'int32u',
        RawConv => '$val + 0xf4',
    },
);

# Samsung composite tags
%Image::ExifTool::Samsung::Composite = (
    GROUPS => { 2 => 'Image' },
    WB_RGGBLevels => {
        Require => {
            0 => 'WB_RGGBLevelsUncorrected',
            1 => 'WB_RGGBLevelsBlack',
        },
        ValueConv => q{
            my @a = split ' ', $val[0];
            my @b = split ' ', $val[1];
            $a[$_] -= $b[$_] foreach 0..$#a;
            return "@a";
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Samsung');

#------------------------------------------------------------------------------
# Encrypt/Decrypt NX10 information
# Inputs: 0) ExifTool ref, 1) value as a string of integers,
#         2) tagInfo hash ref, 3-N) encryption salt values
# Returns: encrypted/decrypted value
# Notes:
# 1) The encryption salt starts with '-' to reverse the encryption algorithm
# 2) Additional salt values are provided when tag stores multiple arrays
#    (in which case the first value of the tag gives the array length)
sub Crypt($$$@)
{
    my ($exifTool, $val, $tagInfo, @salt) = @_;
    my $key = $$exifTool{EncryptionKey} or return undef;
    my $format = $$tagInfo{Writable} || $$tagInfo{Format} or return undef;
    return undef unless $formatMinMax{$format};
    my ($min, $max) = @{$formatMinMax{$format}};
    my @a = split ' ', $val;
    my $newSalt = (@salt > 1) ? 1 : 0;  # skip length entry if this is an array
    my ($i, $sign, $salt, $start);
    for ($i=$newSalt; $i<@a; ++$i) {
        if ($i == $newSalt) {
            $start = $i;
            $salt = shift @salt;
            $sign = ($salt =~ s/^-//) ? -1 : 1;
            $newSalt += $a[0] if @salt;
        }
        $a[$i] += $sign * $$key[($salt+$i-$start) % scalar(@$key)];
        # handle integer wrap-around
        if ($sign > 0) {
            $a[$i] -= $max - $min + 1 if $a[$i] > $max;
        } else {
            $a[$i] += $max - $min + 1 if $a[$i] < $min;
        }
    }
    return "@a";
}

#------------------------------------------------------------------------------
# Process Samsung MP4 INFO data
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessINFO($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $len = $$dirInfo{DirLen};
    my $end = $pos + $len;
    $exifTool->VerboseDir('INFO', undef, $len);
    while ($pos + 8 <= $end) {
        my $tag = substr($$dataPt, $pos, 4);
        my $val = Get32u($dataPt, $pos + 4);
        unless ($$tagTablePtr{$tag}) {
            my $name = "Samsung_INFO_$tag";
            $name =~ tr/-_0-9a-zA-Z//dc;
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, { Name => $name }) if $name;
        }
        $exifTool->HandleTag($tagTablePtr, $tag, $val);
        $pos += 8;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write Samsung STMN maker notes
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Binary data block or undefined on error
sub WriteSTMN($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    # create a Fixup for the PreviewImage
    $$dirInfo{Fixup} = new Image::ExifTool::Fixup;
    my $val = Image::ExifTool::WriteBinaryData($exifTool, $dirInfo, $tagTablePtr);
    # force PreviewImage into the trailer even if it fits in EXIF segment
    $$exifTool{PREVIEW_INFO}{IsTrailer} = 1 if $$exifTool{PREVIEW_INFO};
    return $val;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Samsung - Samsung EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Samsung maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2011, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Tae-Sun Park for decoding a number of tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Samsung Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
