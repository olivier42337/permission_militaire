import { Calendar } from '@fullcalendar/core';
import dayGridPlugin from '@fullcalendar/daygrid';
import interactionPlugin from '@fullcalendar/interaction';
import frLocale from '@fullcalendar/core/locales/fr';

document.addEventListener('DOMContentLoaded', function () {
    let calendarEl = document.getElementById('calendrier');

    if (calendarEl) {
        let calendar = new Calendar(calendarEl, {
            plugins: [dayGridPlugin, interactionPlugin],
            initialView: 'dayGridMonth',
            locale: frLocale,
            events: '/officier/calendrier/data', // ⚠️ route Symfony qui retourne JSON
            editable: false,
            eventClick: function (info) {
                alert('Événement : ' + info.event.title);
            }
        });

        calendar.render();
    }
});
