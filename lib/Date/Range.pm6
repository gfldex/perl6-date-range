use v6.c;

use MONKEY-TYPING;

class Weekday {...}

subset IntWhatever where * ~~ Int|Whatever|Range|Seq|List;

class DateRange {
    has $.year;
    has $.month;
    has $.day;

    multi method ACCEPTS(Date(Dateish) \other){
        other.year ~~ $!year
        && other.month ~~ $!month
        && other.day ~~ $!day
    }

    multi method ACCEPTS(Instant \other){
        other.DateTime ~~ self
    }
}

class DateTimeRange {
    has $.year;
    has $.month;
    has $.day;
    has $.hour;
    has $.minute;
    has $.second;
    has @.weekdays;

    multi method new(IntWhatever $year is copy, IntWhatever $month is copy, IntWhatever $day is copy, IntWhatever $hour is copy, IntWhatever $minute is copy, IntWhatever $second is copy, :&formatter, *%_, :$monday, :$tuesday, :$wednesday, :$thursday, :$friday, :$saturday, :$sunday) {

        $year = $year ~~ Whatever ?? -∞..∞ !! $year;
        $month = $month ~~ Whatever ?? 1..12 !! $month;
        $day = $day ~~ Whatever ?? 0..31 !! $day;
        $hour = $hour ~~ Whatever ?? 0..23 !! $hour;
        $minute = $minute ~~ Whatever ?? 0..59 !! $minute;
        $second = $second ~~ Whatever ?? 0..60 !! $second;

        my @weekdays;
        if any($monday, $tuesday, $wednesday, $thursday, $friday, $saturday, $sunday) {
            @weekdays = ();
            @weekdays.push(1) if $monday;
            @weekdays.push(2) if $tuesday;
            @weekdays.push(3) if $wednesday;
            @weekdays.push(4) if $thursday;
            @weekdays.push(5) if $friday;
            @weekdays.push(6) if $saturday;
            @weekdays.push(7) if $sunday;
        } else {
            @weekdays = 1..7;
        }

        DateTimeRange.new(:$year, :$month, :$day, :$hour, :$minute, :$second, :@weekdays)
    }
    
    multi method new(*@a where .any ~~ Weekday) {
        X::NYI.new( feature => "Weekdays in DateTimeRange" ).throw;
    }

    multi method ACCEPTS(DateTime \other){
        other.year ~~ $!year
        && other.month ~~ $!month
        && other.day ~~ $!day
        && other.hour ~~ $!hour
        && other.minute ~~ $!minute
        && other.second ~~ $!second
    }

    multi method ACCEPTS(Instant \other){
        other.DateTime ~~ self
    }

    multi method Supply {
        my Supplier::Preserving $supply .= new;

        start {
            sub move-iterator-to-next-value($value, $it is rw){
                my $current-value;
                while ($current-value := $it.pull-one) !=:= IterationEnd {
                    last if $current-value >= $value
                }

                $current-value;
            }

            my $now = now.DateTime;
            my $start-year = $now.DateTime.year;
            my $start-month = $now.DateTime.month;
            my $start-day = $now.DateTime.day;
            my $start-hour = $now.DateTime.hour;
            my $start-minute = $now.DateTime.minute;
            my $start-second = $now.DateTime.whole-second;
            my $it-y = ($start-year .. $.year.max).iterator;
            dd $now;
            loop (my Mu $til-y := move-iterator-to-next-value($now.year, $it-y); $til-y !=:= IterationEnd; $til-y := $it-y.pull-one) {
                my $it-m = $.month.cache.iterator;
                loop (my Mu $til-m := move-iterator-to-next-value($start-month, $it-m); $til-m !=:= IterationEnd; $til-m := $it-m.pull-one) {
                    my $it-d = $.day.cache.iterator;
                    loop (my Mu $til-d := move-iterator-to-next-value($start-day, $it-d); $til-d !=:= IterationEnd; $til-d := $it-d.pull-one) {
                        my $it-h = $.hour.cache.iterator;
                        loop (my Mu $til-h := move-iterator-to-next-value($start-hour, $it-h); $til-h !=:= IterationEnd; $til-h := $it-h.pull-one) {
                            my $it-min = $.minute.cache.iterator;
                            loop (my Mu $til-min := move-iterator-to-next-value($start-minute, $it-min); $til-min !=:= IterationEnd; $til-min := $it-min.pull-one) {
                                $start-second = 0 unless $til-min - $start-minute;
                                my $it-s = $.second.cache.iterator;
                                loop (my Mu $til-s = move-iterator-to-next-value($start-second, $it-s); $til-s !=:= IterationEnd; $til-s := $it-s.pull-one) {
                                    sleep 1;
                                    my $instant = DateTime.new($til-y, $til-m, $til-d, $til-h, $til-min, $til-s).Instant;
                                    
                                    say [$til-y, $til-m, $til-d, $til-h, $til-min, $til-s];
                                    say [$instant.DateTime.day-of-week, $.weekdays, $instant.DateTime.day-of-week ∩ $.weekdays];
                                    
                                    next unless $instant.DateTime.day-of-week ∩ $.weekdays;
                                    say "sleep until {$instant.DateTime}";
                                    sleep-until($instant);
                                    $supply.emit(now.DateTime);
                                }
                            }
                            $start-minute = 0;
                        }
                        $start-hour = 0;
                    }
                    $start-day = 0;
                }
                $start-month = 0;
                CATCH { default { $supply.emit(Failure.new($_)) } }
            }
        }

        $supply
    }
}

augment class Date {
    multi method new(IntWhatever $year is copy,IntWhatever $month is copy, IntWhatever $day is copy, :&formatter, *%_) {
        $month ~~ Whatever || 1 <= ($month ~~ Range ?? $month.min !! $month) && ($month ~~ Range ?? $month.max !! $month) <= 12
            or X::OutOfRange.new(:what<Month>, :got($month.perl), :range<1..12>).throw;

        sub DAYS-IN-MONTH(\year, \month) {
            my @days-in-month = 0, 31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31;

            @days-in-month[month] || (month == 2 ?? 28 + Dateish.IS-LEAP-YEAR(year) !! Nil)
        }

        my $valid-day-range = 1..31;

        if $month !~~ Whatever && $month !~~ Range {
            if $year !~~ Whatever {
                $valid-day-range = 1 .. DAYS-IN-MONTH($year, $month);
            } else {
                $valid-day-range = 1 .. DAYS-IN-MONTH(0, $month); # 0 is a known leap year
            }
        }
        
        $day ~~ Whatever || $day ~~ $valid-day-range
            or X::OutOfRange.new(:what<Day>, :got($day.perl), :range($valid-day-range)).throw;

        $year = $year ~~ Whatever ?? -∞..∞ !! $year;
        $month = $month ~~ Whatever ?? 1..12 !! $month;
        $day = $day ~~ Whatever ?? 0..31 !! $day;

        DateRange.new(:$year, :$month, :$day);
    }
}

augment class DateTime {
}

class Weekday {
    has IntWhatever $.weekday;

    multi method new($weekday){
        self.new(:$weekday)
    }

    multi method ACCEPTS(Dateish \other) {
        other.day-of-week ~~ $!weekday
    }
    
    multi method ACCEPTS(Instant \other) {
        other.DateTime.day-of-week ~~ $!weekday
    }
}

constant Monday    is export = Weekday.new(1);
constant Tuesday   is export = Weekday.new(2);
constant Wednesday is export = Weekday.new(3);
constant Thursday  is export = Weekday.new(4);
constant Friday    is export = Weekday.new(5);
constant Saturday  is export = Weekday.new(6);
constant Sunday    is export = Weekday.new(7);

