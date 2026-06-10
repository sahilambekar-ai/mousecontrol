// macOS CGKeyCode definitions matching Models.swift
const availableKeys = [
    { code: 123, name: "Left Arrow", jsKey: "ArrowLeft" },
    { code: 124, name: "Right Arrow", jsKey: "ArrowRight" },
    { code: 125, name: "Down Arrow", jsKey: "ArrowDown" },
    { code: 126, name: "Up Arrow", jsKey: "ArrowUp" },
    { code: 49, name: "Space", jsKey: " " },
    { code: 36, name: "Return", jsKey: "Enter" },
    { code: 48, name: "Tab", jsKey: "Tab" },
    { code: 53, name: "Escape", jsKey: "Escape" },
    { code: 51, name: "Backspace", jsKey: "Backspace" },
    { code: 117, name: "Delete", jsKey: "Delete" },
    { code: 116, name: "Page Up", jsKey: "PageUp" },
    { code: 121, name: "Page Down", jsKey: "PageDown" },
    { code: 115, name: "Home", jsKey: "Home" },
    { code: 119, name: "End", jsKey: "End" },
    
    // Letters
    { code: 0, name: "A", jsKey: "a" },
    { code: 11, name: "B", jsKey: "b" },
    { code: 8, name: "C", jsKey: "c" },
    { code: 2, name: "D", jsKey: "d" },
    { code: 14, name: "E", jsKey: "e" },
    { code: 3, name: "F", jsKey: "f" },
    { code: 5, name: "G", jsKey: "g" },
    { code: 4, name: "H", jsKey: "h" },
    { code: 34, name: "I", jsKey: "i" },
    { code: 38, name: "J", jsKey: "j" },
    { code: 40, name: "K", jsKey: "k" },
    { code: 37, name: "L", jsKey: "l" },
    { code: 46, name: "M", jsKey: "m" },
    { code: 45, name: "N", jsKey: "n" },
    { code: 31, name: "O", jsKey: "o" },
    { code: 35, name: "P", jsKey: "p" },
    { code: 12, name: "Q", jsKey: "q" },
    { code: 15, name: "R", jsKey: "r" },
    { code: 1, name: "S", jsKey: "s" },
    { code: 17, name: "T", jsKey: "t" },
    { code: 32, name: "U", jsKey: "u" },
    { code: 9, name: "V", jsKey: "v" },
    { code: 13, name: "W", jsKey: "w" },
    { code: 7, name: "X", jsKey: "x" },
    { code: 16, name: "Y", jsKey: "y" },
    { code: 6, name: "Z", jsKey: "z" },
    
    // Numbers
    { code: 18, name: "1", jsKey: "1" },
    { code: 19, name: "2", jsKey: "2" },
    { code: 20, name: "3", jsKey: "3" },
    { code: 21, name: "4", jsKey: "4" },
    { code: 23, name: "5", jsKey: "5" },
    { code: 22, name: "6", jsKey: "6" },
    { code: 26, name: "7", jsKey: "7" },
    { code: 28, name: "8", jsKey: "8" },
    { code: 25, name: "9", jsKey: "9" },
    { code: 29, name: "0", jsKey: "0" },
    
    // Function keys
    { code: 122, name: "F1", jsKey: "F1" },
    { code: 120, name: "F2", jsKey: "F2" },
    { code: 99, name: "F3", jsKey: "F3" },
    { code: 118, name: "F4", jsKey: "F4" },
    { code: 96, name: "F5", jsKey: "F5" },
    { code: 97, name: "F6", jsKey: "F6" },
    { code: 98, name: "F7", jsKey: "F7" },
    { code: 100, name: "F8", jsKey: "F8" },
    { code: 101, name: "F9", jsKey: "F9" },
    { code: 109, name: "F10", jsKey: "F10" },
    { code: 103, name: "F11", jsKey: "F11" },
    { code: 111, name: "F12", jsKey: "F12" }
];

const API_BASE = "http://localhost:9002/api";
let currentMappings = [];
let connectedMice = ["All Devices"];
let isDaemonOnline = false;
let isRecordingKey = false;
let isRecordingMouse = false;
let recordMouseTimer = null;
let initialLastTrigger = null;

// UI Elements
const statusBadge = document.getElementById("status-badge");
const statusLabel = document.getElementById("status-label");
const globalToggle = document.getElementById("global-toggle");
const engineStatusText = document.getElementById("engine-status-text");
const lastMouseTriggerText = document.getElementById("last-mouse-trigger");
const lastKeyboardActionText = document.getElementById("last-keyboard-action");
const activeDeviceText = document.getElementById("active-device");
const mappingsList = document.getElementById("mappings-list");
const addMappingBtn = document.getElementById("add-mapping-btn");
const copyBtn = document.getElementById("copy-command-btn");

// Modal Elements
const mappingModal = document.getElementById("mapping-modal");
const modalTitle = document.getElementById("modal-title");
const mappingForm = document.getElementById("mapping-form");
const mappingIdInput = document.getElementById("mapping-id");
const modalCloseBtn = document.getElementById("modal-close-btn");
const modalCancelBtn = document.getElementById("modal-cancel-btn");
const recordKeyBtn = document.getElementById("record-key-btn");
const recordMouseBtn = document.getElementById("record-mouse-btn");
const keySelector = document.getElementById("key-selector");
const deviceSelector = document.getElementById("device-selector");
const typeButtons = document.querySelectorAll(".type-btn");
const buttonConfigGroup = document.getElementById("button-config-group");
const scrollConfigGroup = document.getElementById("scroll-config-group");
const buttonSelector = document.getElementById("button-selector");
const scrollSelector = document.getElementById("scroll-selector");
const recordingIndicator = document.getElementById("recording-indicator");

// Modifiers Checkboxes
const modCmd = document.getElementById("mod-cmd");
const modCtrl = document.getElementById("mod-ctrl");
const modOpt = document.getElementById("mod-opt");
const modShift = document.getElementById("mod-shift");

// Initialize key selector dropdown
function initializeDropdowns() {
    keySelector.innerHTML = "";
    availableKeys.forEach(k => {
        const option = document.createElement("option");
        option.value = k.code;
        option.textContent = k.name;
        keySelector.appendChild(option);
    });
}

// Helper: generate UUID (v4 equivalent)
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// Show a toast message
function showToast(message, type = "info") {
    const container = document.getElementById("toast-container");
    const toast = document.createElement("div");
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = "0";
        toast.style.transform = "translateY(-10px)";
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Check status of daemon
async function checkStatus() {
    try {
        const res = await fetch(`${API_BASE}/status`, { mode: "cors" });
        if (!res.ok) throw new Error("Status failed");
        const status = await res.json();
        
        isDaemonOnline = true;
        updateUIWithStatus(status);
    } catch (err) {
        if (isDaemonOnline) {
            isDaemonOnline = false;
            updateUIOffline();
        }
    }
}

function updateUIWithStatus(status) {
    statusBadge.className = "status-indicator online";
    statusLabel.textContent = "Online";
    globalToggle.disabled = false;
    globalToggle.checked = status.isEnabled;
    addMappingBtn.disabled = false;
    
    engineStatusText.textContent = status.isEnabled 
        ? "Active & listening to mouse events" 
        : "Disabled. Click switch to activate.";

    // Update activity indicators
    if (status.lastActiveTrigger) {
        let text = "";
        if (status.lastActiveTrigger.type === "button") {
            const btn = status.lastActiveTrigger.buttonNumber;
            text = btn === 0 ? "Left Click" : btn === 1 ? "Right Click" : btn === 2 ? "Middle Click" : `Button ${btn}`;
        } else {
            text = `Scroll: ${status.lastActiveTrigger.scrollDirection}`;
        }
        
        if (lastMouseTriggerText.textContent !== text) {
            lastMouseTriggerText.textContent = text;
            flashElement(lastMouseTriggerText);
            
            // Check if any mapping matches to flash it
            const matchedRow = findMappingRowByTrigger(status.lastActiveTrigger);
            if (matchedRow) {
                matchedRow.classList.add("active-flash");
                setTimeout(() => matchedRow.classList.remove("active-flash"), 400);
            }
        }
    } else {
        lastMouseTriggerText.textContent = "-";
    }

    if (status.lastActiveKey && status.lastActiveKey !== "None") {
        if (lastKeyboardActionText.textContent !== status.lastActiveKey) {
            lastKeyboardActionText.textContent = status.lastActiveKey;
            flashElement(lastKeyboardActionText);
        }
    } else {
        lastKeyboardActionText.textContent = "-";
    }

    activeDeviceText.textContent = status.lastActiveDevice || "None";

    // Update mice devices dropdown if list changed
    if (JSON.stringify(connectedMice) !== JSON.stringify(status.connectedMice)) {
        connectedMice = status.connectedMice || ["All Devices"];
        updateDeviceDropdown();
    }

    // Load mappings if they changed
    if (JSON.stringify(currentMappings) !== JSON.stringify(status.mappings)) {
        currentMappings = status.mappings || [];
        renderMappingsList();
    }
}

function findMappingRowByTrigger(trigger) {
    const rows = document.querySelectorAll(".mapping-row");
    for (let row of rows) {
        const rowTriggerType = row.dataset.triggerType;
        const rowTriggerVal = row.dataset.triggerVal;
        
        if (trigger.type === rowTriggerType) {
            if (trigger.type === "button" && String(trigger.buttonNumber) === rowTriggerVal) {
                return row;
            }
            if (trigger.type === "scroll" && trigger.scrollDirection === rowTriggerVal) {
                return row;
            }
        }
    }
    return null;
}

function updateUIOffline() {
    statusBadge.className = "status-indicator offline";
    statusLabel.textContent = "Offline";
    globalToggle.disabled = true;
    globalToggle.checked = false;
    addMappingBtn.disabled = true;
    engineStatusText.textContent = "Waiting for daemon service connection...";
    lastMouseTriggerText.textContent = "-";
    lastKeyboardActionText.textContent = "-";
    activeDeviceText.textContent = "None";
    
    mappingsList.innerHTML = `
        <div class="empty-state">
            <p>Daemon service is offline. Follow the instructions to start it.</p>
        </div>
    `;
    currentMappings = [];
}

function flashElement(el) {
    el.style.color = "var(--primary)";
    el.style.transform = "scale(1.05)";
    setTimeout(() => {
        el.style.color = "";
        el.style.transform = "";
    }, 300);
}

function updateDeviceDropdown() {
    const val = deviceSelector.value;
    deviceSelector.innerHTML = "";
    connectedMice.forEach(m => {
        const option = document.createElement("option");
        option.value = m;
        option.textContent = m;
        deviceSelector.appendChild(option);
    });
    // Keep selection if it's still available
    if (connectedMice.includes(val)) {
        deviceSelector.value = val;
    } else {
        deviceSelector.value = "All Devices";
    }
}

function getKeyCodeDisplayName(code) {
    const k = availableKeys.find(key => key.code === code);
    return k ? k.name : `Key ${code}`;
}

function getModifierString(modifiers) {
    const parts = [];
    if (modifiers.control) parts.push("⌃ Control");
    if (modifiers.option) parts.push("⌥ Option");
    if (modifiers.shift) parts.push("⇧ Shift");
    if (modifiers.command) parts.push("⌘ Command");
    return parts;
}

function renderMappingsList() {
    mappingsList.innerHTML = "";
    if (currentMappings.length === 0) {
        mappingsList.innerHTML = `
            <div class="empty-state">
                <p>No active mouse mappings configured. Click '+ Add Mapping' to create one.</p>
            </div>
        `;
        return;
    }

    currentMappings.forEach(mapping => {
        const row = document.createElement("div");
        row.className = "mapping-row";
        
        let triggerName = "";
        let triggerVal = "";
        if (mapping.trigger.type === "button") {
            const btnNum = mapping.trigger.buttonNumber;
            triggerName = btnNum === 0 ? "Left Click" : btnNum === 1 ? "Right Click" : btnNum === 2 ? "Middle Click" : `Mouse Button ${btnNum}`;
            triggerVal = btnNum;
            row.dataset.triggerType = "button";
            row.dataset.triggerVal = btnNum;
        } else {
            triggerName = `Scroll ${mapping.trigger.scrollDirection}`;
            triggerVal = mapping.trigger.scrollDirection;
            row.dataset.triggerType = "scroll";
            row.dataset.triggerVal = mapping.trigger.scrollDirection;
        }

        const mods = getModifierString(mapping.shortcut.modifiers);
        const keyName = getKeyCodeDisplayName(mapping.shortcut.keyCode);

        row.innerHTML = `
            <div class="mapping-info">
                <div class="mapping-trigger">
                    <span class="trigger-label">${triggerName}</span>
                    <span class="device-label">${mapping.deviceName}</span>
                </div>
                <div class="arrow-icon">→</div>
                <div class="shortcut-display">
                    ${mods.map(m => `<kbd class="key-cap">${m.split(" ")[0]}</kbd>`).join("")}
                    <kbd class="key-cap">${keyName}</kbd>
                </div>
            </div>
            <div class="mapping-actions">
                <label class="switch-container">
                    <input type="checkbox" class="mapping-toggle" data-id="${mapping.id}" ${mapping.isEnabled ? "checked" : ""}>
                    <span class="slider"></span>
                </label>
                <button class="action-icon-btn edit-mapping" data-id="${mapping.id}" title="Edit Mapping">✏️</button>
                <button class="action-icon-btn delete delete-mapping" data-id="${mapping.id}" title="Delete Mapping">🗑️</button>
            </div>
        `;
        
        mappingsList.appendChild(row);
    });

    // Add event listeners to dynamically generated elements
    document.querySelectorAll(".mapping-toggle").forEach(el => {
        el.addEventListener("change", (e) => toggleMapping(e.target.dataset.id, e.target.checked));
    });
    document.querySelectorAll(".edit-mapping").forEach(el => {
        el.addEventListener("click", (e) => openEditModal(e.target.dataset.id));
    });
    document.querySelectorAll(".delete-mapping").forEach(el => {
        el.addEventListener("click", (e) => deleteMapping(e.target.dataset.id));
    });
}

// API Actions
async function toggleGlobalEngine(enabled) {
    try {
        const res = await fetch(`${API_BASE}/toggle`, {
            method: "POST",
            mode: "cors"
        });
        if (!res.ok) throw new Error("Toggle failed");
        showToast(enabled ? "Remapping engine enabled!" : "Remapping engine disabled.", "info");
        checkStatus();
    } catch (err) {
        showToast("Failed to toggle remapping engine.", "error");
    }
}

async function toggleMapping(id, isEnabled) {
    const updated = currentMappings.map(m => {
        if (m.id === id) {
            return { ...m, isEnabled };
        }
        return m;
    });
    
    await saveConfig(updated, isEnabled ? "Mapping enabled" : "Mapping disabled");
}

async function deleteMapping(id) {
    if (!confirm("Are you sure you want to delete this mapping?")) return;
    const updated = currentMappings.filter(m => m.id !== id);
    await saveConfig(updated, "Mapping deleted");
}

async function saveConfig(newMappings, successMsg = "Configuration saved") {
    try {
        const res = await fetch(`${API_BASE}/config`, {
            method: "POST",
            mode: "cors",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(newMappings)
        });
        if (!res.ok) throw new Error("Save config failed");
        
        currentMappings = newMappings;
        renderMappingsList();
        showToast(successMsg, "success");
    } catch (err) {
        showToast("Failed to save configuration to daemon.", "error");
    }
}

// Modal Form handling
function openAddModal() {
    modalTitle.textContent = "Create New Mapping";
    mappingIdInput.value = "";
    mappingForm.reset();
    
    // Default form configuration
    setTriggerType("button");
    buttonSelector.value = "4"; // Default side back button
    deviceSelector.value = "All Devices";
    
    mappingModal.classList.add("open");
}

function openEditModal(id) {
    const m = currentMappings.find(x => x.id === id);
    if (!m) return;

    modalTitle.textContent = "Edit Mouse Mapping";
    mappingIdInput.value = m.id;
    
    // Set trigger type
    setTriggerType(m.trigger.type);
    if (m.trigger.type === "button") {
        buttonSelector.value = String(m.trigger.buttonNumber);
    } else {
        scrollSelector.value = m.trigger.scrollDirection;
    }

    // Set shortcuts
    modCmd.checked = m.shortcut.modifiers.command;
    modCtrl.checked = m.shortcut.modifiers.control;
    modOpt.checked = m.shortcut.modifiers.option;
    modShift.checked = m.shortcut.modifiers.shift;
    keySelector.value = String(m.shortcut.keyCode);
    
    // Device selection
    deviceSelector.value = m.deviceName || "All Devices";

    mappingModal.classList.add("open");
}

function setTriggerType(type) {
    typeButtons.forEach(btn => {
        if (btn.dataset.type === type) {
            btn.classList.add("active");
        } else {
            btn.classList.remove("active");
        }
    });

    if (type === "button") {
        buttonConfigGroup.classList.remove("hidden");
        scrollConfigGroup.classList.add("hidden");
    } else {
        buttonConfigGroup.classList.add("hidden");
        scrollConfigGroup.classList.remove("hidden");
    }
}

// Handle trigger type buttons
typeButtons.forEach(btn => {
    btn.addEventListener("click", () => {
        setTriggerType(btn.dataset.type);
    });
});

// Record Keyboard Key
recordKeyBtn.addEventListener("click", () => {
    isRecordingKey = true;
    recordingIndicator.textContent = "PRESS ANY KEY ON YOUR KEYBOARD NOW...";
    recordingIndicator.classList.add("active");
    recordKeyBtn.classList.add("btn-primary");
});

document.addEventListener("keydown", (e) => {
    if (!isRecordingKey) return;
    
    // Prevent default browser shortcuts like Ctrl+P, Command+R, etc. while recording
    e.preventDefault();
    e.stopPropagation();

    // Map jsKey to available keys
    const match = availableKeys.find(k => k.jsKey.toLowerCase() === e.key.toLowerCase());
    if (match) {
        keySelector.value = String(match.code);
        
        // Also capture modifiers automatically
        modCmd.checked = e.metaKey;
        modCtrl.checked = e.ctrlKey;
        modOpt.checked = e.altKey;
        modShift.checked = e.shiftKey;
        
        showToast(`Recorded key: ${match.name}`, "info");
    } else {
        // Fallback for special keys not handled specifically
        showToast(`Key '${e.key}' not directly supported. Select from list instead.`, "info");
    }

    // Reset recording state
    isRecordingKey = false;
    recordingIndicator.textContent = "Click 'Record Key' and press a key on your keyboard.";
    recordingIndicator.classList.remove("active");
    recordKeyBtn.classList.remove("btn-primary");
}, true); // Capture phase to swallow browser action

// Record Mouse click using daemon poll
recordMouseBtn.addEventListener("click", async () => {
    if (isRecordingMouse) return;
    
    try {
        // Fetch current status to get initial trigger
        const res = await fetch(`${API_BASE}/status`);
        const data = await res.json();
        initialLastTrigger = data.lastActiveTrigger;
    } catch (e) {
        initialLastTrigger = null;
    }

    isRecordingMouse = true;
    recordMouseBtn.textContent = "Listening...";
    recordMouseBtn.classList.add("btn-primary");
    showToast("Press any mouse button or scroll to capture trigger...", "info");

    let count = 0;
    recordMouseTimer = setInterval(async () => {
        count++;
        if (count > 50) { // 5 seconds timeout
            stopMouseRecording(false);
            showToast("Mouse click recording timed out.", "info");
            return;
        }

        try {
            const res = await fetch(`${API_BASE}/status`);
            const status = await res.json();
            
            // Check if lastActiveTrigger changed
            if (status.lastActiveTrigger && 
                JSON.stringify(status.lastActiveTrigger) !== JSON.stringify(initialLastTrigger)) {
                
                const trigger = status.lastActiveTrigger;
                setTriggerType(trigger.type);
                
                if (trigger.type === "button") {
                    buttonSelector.value = String(trigger.buttonNumber);
                } else {
                    scrollSelector.value = trigger.scrollDirection;
                }
                
                stopMouseRecording(true);
            }
        } catch (err) {
            stopMouseRecording(false);
        }
    }, 100);
});

function stopMouseRecording(success) {
    clearInterval(recordMouseTimer);
    isRecordingMouse = false;
    recordMouseBtn.textContent = "Record Click";
    recordMouseBtn.classList.remove("btn-primary");
    if (success) {
        showToast("Mouse trigger recorded successfully!", "success");
    }
}

// Close modals
function closeModal() {
    mappingModal.classList.remove("open");
    stopMouseRecording(false);
    isRecordingKey = false;
    recordingIndicator.textContent = "Click 'Record Key' and press a key on your keyboard.";
    recordingIndicator.classList.remove("active");
    recordKeyBtn.classList.remove("btn-primary");
}

modalCloseBtn.addEventListener("click", closeModal);
modalCancelBtn.addEventListener("click", closeModal);

// Form Submission
mappingForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    
    const activeTypeBtn = document.querySelector(".type-btn.active");
    const triggerType = activeTypeBtn.dataset.type;
    
    let trigger = {};
    if (triggerType === "button") {
        trigger = {
            type: "button",
            buttonNumber: parseInt(buttonSelector.value, 10)
        };
    } else {
        trigger = {
            type: "scroll",
            scrollDirection: scrollSelector.value
        };
    }

    const shortcut = {
        keyCode: parseInt(keySelector.value, 10),
        modifiers: {
            command: modCmd.checked,
            control: modCtrl.checked,
            option: modOpt.checked,
            shift: modShift.checked
        }
    };

    const deviceName = deviceSelector.value;
    const existingId = mappingIdInput.value;
    
    let updatedMappings = [...currentMappings];
    if (existingId) {
        // Edit Mode
        updatedMappings = updatedMappings.map(m => {
            if (m.id === existingId) {
                return { ...m, trigger, shortcut, deviceName };
            }
            return m;
        });
    } else {
        // Add Mode
        const newMapping = {
            id: generateUUID(),
            trigger,
            shortcut,
            isEnabled: true,
            deviceName
        };
        updatedMappings.push(newMapping);
    }

    await saveConfig(updatedMappings, existingId ? "Mapping updated successfully" : "New mapping added successfully");
    closeModal();
});

// Copy button behavior
copyBtn.addEventListener("click", () => {
    const code = document.querySelector(".terminal-body code").innerText;
    navigator.clipboard.writeText(code).then(() => {
        showToast("Command copied to clipboard!", "success");
    }).catch(() => {
        showToast("Failed to copy command.", "error");
    });
});

// Event Listeners
globalToggle.addEventListener("change", (e) => {
    toggleGlobalEngine(e.target.checked);
});
addMappingBtn.addEventListener("click", openAddModal);

// Start polling status
initializeDropdowns();
updateUIOffline();
checkStatus();
setInterval(checkStatus, 1500);
