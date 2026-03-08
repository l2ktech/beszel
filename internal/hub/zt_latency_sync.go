package hub

import (
	"encoding/json"
	"net/http"

	"github.com/pocketbase/pocketbase/core"
)

type ztLatencySyncPayload struct {
	Updates []ztLatencySyncUpdate `json:"updates"`
}

type ztLatencySyncUpdate struct {
	SystemID string         `json:"systemId"`
	Info     map[string]any `json:"info"`
	ZtStats  map[string]any `json:"ztStats"`
}

var ztLatencyNativeInfoKeys = map[string]struct{}{
	"h": {}, "k": {}, "c": {}, "t": {}, "m": {}, "u": {}, "cpu": {}, "mp": {}, "dp": {},
	"b": {}, "v": {}, "p": {}, "g": {}, "dt": {}, "os": {}, "l1": {}, "l5": {}, "l15": {},
	"bb": {}, "la": {}, "ct": {}, "efs": {}, "sv": {}, "bat": {},
}

func mergeCustomSystemInfo(existing any, custom map[string]any) (map[string]any, error) {
	merged := map[string]any{}
	if existing != nil {
		existingBytes, err := json.Marshal(existing)
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(existingBytes, &merged); err != nil {
			return nil, err
		}
	}
	for key, value := range custom {
		if _, isNative := ztLatencyNativeInfoKeys[key]; isNative {
			continue
		}
		merged[key] = value
	}
	return merged, nil
}

func (h *Hub) upsertZtLatencySync(e *core.RequestEvent) error {
	payload := ztLatencySyncPayload{}
	if err := json.NewDecoder(e.Request.Body).Decode(&payload); err != nil {
		return e.JSON(http.StatusBadRequest, map[string]string{"error": "invalid json body"})
	}
	if len(payload.Updates) == 0 {
		return e.JSON(http.StatusBadRequest, map[string]string{"error": "updates are required"})
	}

	err := h.RunInTransaction(func(txApp core.App) error {
		systemStatsCollection, err := txApp.FindCachedCollectionByNameOrId("system_stats")
		if err != nil {
			return err
		}
		for _, update := range payload.Updates {
			if update.SystemID == "" {
				return httpError("systemId is required", http.StatusBadRequest)
			}

			systemRecord, err := txApp.FindRecordById("systems", update.SystemID)
			if err != nil {
				return httpError("system not found", http.StatusNotFound)
			}

			mergedInfo, err := mergeCustomSystemInfo(systemRecord.Get("info"), update.Info)
			if err != nil {
				return err
			}
			systemRecord.Set("info", mergedInfo)
			if err := txApp.SaveNoValidate(systemRecord); err != nil {
				return err
			}

			if len(update.ZtStats) == 0 {
				continue
			}
			statsRecord := core.NewRecord(systemStatsCollection)
			statsRecord.Set("system", systemRecord.Id)
			statsRecord.Set("stats", update.ZtStats)
			statsRecord.Set("type", "zt1m")
			if err := txApp.SaveNoValidate(statsRecord); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		if httpErr, ok := err.(*requestHTTPError); ok {
			return e.JSON(httpErr.status, map[string]string{"error": httpErr.message})
		}
		return e.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return e.JSON(http.StatusOK, map[string]any{"status": "ok", "updated": len(payload.Updates)})
}

type requestHTTPError struct {
	message string
	status  int
}

func (e *requestHTTPError) Error() string {
	return e.message
}

func httpError(message string, status int) error {
	return &requestHTTPError{message: message, status: status}
}
