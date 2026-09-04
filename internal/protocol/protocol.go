package protocol

const (
	RequestSubmit   = "submit"
	RequestCancel   = "cancel"
	RequestShutdown = "shutdown"

	EventStarted        = "started"
	EventAssistantDelta = "assistant_delta"
	EventAssistantDone  = "assistant_done"
	EventCancelled      = "cancelled"
	EventError          = "error"
)

type Request struct {
	Type    string `json:"type"`
	ID      string `json:"id,omitempty"`
	Content string `json:"content,omitempty"`
}

type Event struct {
	Type    string `json:"type"`
	ID      string `json:"id,omitempty"`
	Content string `json:"content,omitempty"`
	Message string `json:"message,omitempty"`
}
