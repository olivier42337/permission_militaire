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
            events: '/militaire/calendrier/data', // ✅ Route militaire corrigée
            editable: false,
            eventClick: function (info) {
                let event = info.event;
                let details = `Événement: ${event.title}\n`;
                
                if (event.extendedProps.type === 'permission') {
                    details += `Type: Permission\n`;
                    details += `Statut: ${event.extendedProps.statut}\n`;
                    if (event.extendedProps.motif) {
                        details += `Motif: ${event.extendedProps.motif}\n`;
                    }
                } else if (event.extendedProps.type === 'programme') {
                    details += `Type: ${event.title}\n`;
                    if (event.extendedProps.description) {
                        details += `Description: ${event.extendedProps.description}\n`;
                    }
                }
                
                details += `Du: ${event.start ? event.start.toLocaleDateString('fr-FR') : ''}\n`;
                details += `Au: ${event.end ? new Date(event.end.getTime() - 24 * 60 * 60 * 1000).toLocaleDateString('fr-FR') : ''}`;
                
                alert(details);
            },
            // Rafraîchissement automatique toutes les 30 secondes
            eventSources: [
                {
                    url: '/militaire/calendrier/data',
                    method: 'GET'
                }
            ]
        });

        calendar.render();

        // Optionnel: Rafraîchir le calendrier toutes les 30 secondes
        setInterval(() => {
            calendar.refetchEvents();
        }, 30000);
    }
});