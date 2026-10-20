/* Include the actual pinned handlers, rather than reimplementing their policy. */
#define main slurp_entrypoint
#include "main.c"
#undef main

static void expect_box(struct slurp_box box, int x, int y, int w, int h) {
	assert(box.x == x && box.y == y && box.width == w && box.height == h);
}

static void begin(struct slurp_seat *seat, int x, int y) {
	seat->state->running = true;
	seat->pointer_selection.x = x;
	seat->pointer_selection.y = y;
	seat_update_selection(seat);
	handle_selection_start(seat, &seat->pointer_selection);
}

static void move(struct slurp_seat *seat, int x, int y) {
	seat->pointer_selection.x = x;
	seat->pointer_selection.y = y;
	handle_active_selection_motion(seat, &seat->pointer_selection);
}

static struct slurp_box finish(struct slurp_seat *seat) {
	handle_selection_end(seat, &seat->pointer_selection);
	assert(!seat->state->running);
	return seat->state->result;
}

int main(void) {
	struct slurp_state state = {0};
	struct slurp_seat seat = {.state = &state};
	struct slurp_box output = {.x = 0, .y = 0, .width = 1920, .height = 1080};
	struct slurp_box tile = {.x = 10, .y = 30, .width = 900, .height = 1000};
	struct slurp_box floating = {.x = 100, .y = 100, .width = 200, .height = 150};
	wl_list_init(&state.boxes);
	wl_list_insert(&state.boxes, &output.link);
	wl_list_insert(&state.boxes, &tile.link);
	wl_list_insert(&state.boxes, &floating.link);

	begin(&seat, 50, 50); /* Click a tile. */
	expect_box(finish(&seat), 10, 30, 900, 1000);
	begin(&seat, 1, 1); /* Click a gap. */
	expect_box(finish(&seat), 0, 0, 1920, 1080);
	begin(&seat, 150, 150); /* Smallest overlapping rectangle wins. */
	expect_box(finish(&seat), 100, 100, 200, 150);

	begin(&seat, 50, 50);
	move(&seat, 53, 47); /* Wobble does not turn a click into an area. */
	assert(!seat.pointer_selection.drag_started);
	expect_box(finish(&seat), 10, 30, 900, 1000);
	begin(&seat, 1, 1);
	move(&seat, 3, 3);
	expect_box(finish(&seat), 0, 0, 1920, 1080);

	begin(&seat, 50, 50); /* Drag starting inside a tile. */
	move(&seat, 250, 175);
	expect_box(finish(&seat), 50, 50, 201, 126);
	begin(&seat, 1, 1); /* Drag starting in a gap. */
	move(&seat, 200, 100);
	expect_box(finish(&seat), 1, 1, 200, 100);
	begin(&seat, 250, 175); /* Reverse direction. */
	move(&seat, 50, 50);
	expect_box(finish(&seat), 50, 50, 201, 126);
	begin(&seat, 50, 50);
	move(&seat, 54, 50); /* Crossing the threshold latches area mode. */
	assert(seat.pointer_selection.drag_started);
	move(&seat, 51, 51);
	expect_box(finish(&seat), 50, 50, 2, 2);

	begin(&seat, 50, 50); /* A new gesture resets the drag latch. */
	move(&seat, 51, 51);
	expect_box(finish(&seat), 10, 30, 900, 1000);
	begin(&seat, 1, 1); /* Cross-output coordinates are not clipped to a tile. */
	move(&seat, -200, -100);
	expect_box(finish(&seat), -200, -100, 202, 102);
	puts("PASS: tile, gap, overlap, jitter, forward/reverse/cross-output drag and reset");
}
