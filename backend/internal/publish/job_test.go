package publish

import (
	"testing"
	"time"
)

func TestRetryDelayIncreases(t *testing.T) {
	var prev time.Duration
	for attempt := 1; attempt <= len(retryDelays); attempt++ {
		d := retryDelay(attempt)
		if d <= prev {
			t.Fatalf("attempt %d: delay %v ต้องมากกว่าครั้งก่อน %v", attempt, d, prev)
		}
		prev = d
	}
}

// ค่าที่เกินตารางต้องไม่ทำให้ panic และต้องหยุดที่ค่าสูงสุด
func TestRetryDelayClamps(t *testing.T) {
	max := retryDelays[len(retryDelays)-1]

	for _, attempt := range []int{-5, 0, 99} {
		if d := retryDelay(attempt); d < retryDelays[0] || d > max {
			t.Fatalf("attempt %d ได้ delay %v ซึ่งอยู่นอกช่วงที่ควรเป็น", attempt, d)
		}
	}
	if retryDelay(99) != max {
		t.Fatalf("attempt เกินตารางต้องได้ค่าสูงสุด %v", max)
	}
}

// ยิ่งรอนาน ยิ่งถามห่างขึ้น — กันไม่ให้เปลืองโควตา API ตอนคลิปยาวกำลังประมวลผล
func TestPollDelayBacksOff(t *testing.T) {
	cases := []struct {
		elapsed time.Duration
		want    time.Duration
	}{
		{10 * time.Second, pollDelay(1)},
		{2 * time.Minute, pollDelay(2)},
		{5 * time.Minute, pollDelay(3)},
		{20 * time.Minute, pollDelay(4)},
	}

	var prev time.Duration
	for _, c := range cases {
		got := pollDelayFor(c.elapsed)
		if got != c.want {
			t.Fatalf("elapsed %v: ได้ %v want %v", c.elapsed, got, c.want)
		}
		if got < prev {
			t.Fatalf("elapsed %v: delay ต้องไม่ลดลง (%v < %v)", c.elapsed, got, prev)
		}
		prev = got
	}
}

func TestStatusIsTerminal(t *testing.T) {
	terminal := []Status{StatusPublished, StatusFailed, StatusCancelled}
	running := []Status{StatusScheduled, StatusQueued, StatusUploading, StatusProcessing}

	for _, s := range terminal {
		if !s.IsTerminal() {
			t.Fatalf("%s ต้องเป็นสถานะปลายทาง", s)
		}
	}
	for _, s := range running {
		if s.IsTerminal() {
			t.Fatalf("%s ยังไม่ใช่สถานะปลายทาง", s)
		}
	}
}
