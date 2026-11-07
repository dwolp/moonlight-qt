#pragma once

#include <QTimer>
#include <QEvent>

#include "SDL_compat.h"

#include "settings/streamingpreferences.h"

class SdlGamepadKeyNavigation : public QObject
{
    Q_OBJECT

public:
    SdlGamepadKeyNavigation(StreamingPreferences* prefs);

    ~SdlGamepadKeyNavigation();

    Q_INVOKABLE void enable();

    Q_INVOKABLE void disable();

    Q_INVOKABLE void notifyWindowFocus(bool hasFocus);

    Q_INVOKABLE void setUiNavMode(bool settingsMode);

    Q_INVOKABLE int getConnectedGamepads();

private:
    void sendKey(QEvent::Type type, Qt::Key key, Qt::KeyboardModifiers modifiers = Qt::NoModifier, bool autoRepeat = false);

    void sendRepeatableKey(QEvent::Type type, int button, Qt::Key key, Qt::KeyboardModifiers modifiers = Qt::NoModifier);

    void stopKeyRepeat();

    void updateTimerState();

private slots:
    void onPollingTimerFired();

private:
    StreamingPreferences* m_Prefs;
    QTimer* m_PollingTimer;
    QList<SDL_GameController*> m_Gamepads;
    bool m_Enabled;
    bool m_UiNavMode;
    bool m_FirstPoll;
    bool m_HasFocus;
    Uint32 m_LastAxisNavigationEventTime;

    // State for auto-repeating a held D-pad direction
    int m_RepeatButton;
    Qt::Key m_RepeatKey;
    Qt::KeyboardModifiers m_RepeatModifiers;
    Uint32 m_NextRepeatTime;
};
