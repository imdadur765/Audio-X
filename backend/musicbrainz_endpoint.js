// Get Credits from MusicBrainz (More comprehensive credits data)
app.get('/api/musicbrainz', async (req, res) => {
    try {
        const { artist, track } = req.query;

        if (!artist || !track) {
            return res.status(400).json({ error: 'Artist and track parameters are required' });
        }

        // Step 1: Search for the recording
        const searchUrl = `https://musicbrainz.org/ws/2/recording/?query=artist:"${encodeURIComponent(artist)}" AND recording:"${encodeURIComponent(track)}"&fmt=json&limit=1`;

        const searchResponse = await axios.get(searchUrl, {
            headers: {
                'User-Agent': 'AudioX/1.0.0 (https://audio-x.onrender.com)'
            }
        });

        if (!searchResponse.data.recordings || searchResponse.data.recordings.length === 0) {
            return res.status(404).json({ error: 'Recording not found' });
        }

        const recording = searchResponse.data.recordings[0];
        const recordingId = recording.id;

        // Step 2: Get detailed recording info with relationships
        const detailsUrl = `https://musicbrainz.org/ws/2/recording/${recordingId}?inc=artist-credits+releases+work-rels+artist-rels&fmt=json`;

        const detailsResponse = await axios.get(detailsUrl, {
            headers: {
                'User-Agent': 'AudioX/1.0.0 (https://audio-x.onrender.com)'
            }
        });

        const credits = {
            title: recording.title,
            artist: recording['artist-credit'] ? recording['artist-credit'].map(ac => ac.name).join(', ') : artist,
            producers: [],
            writers: [],
            composers: []
        };

        // Extract relationships
        if (detailsResponse.data.relations) {
            detailsResponse.data.relations.forEach(rel => {
                if (rel.type === 'producer' && rel.artist) {
                    credits.producers.push(rel.artist.name);
                }
                if (rel.type === 'composer' && rel.artist) {
                    credits.composers.push(rel.artist.name);
                }
            });
        }

        res.json(credits);

    } catch (error) {
        console.error('Error fetching MusicBrainz data:', error.message);
        res.status(500).json({ error: 'Failed to fetch credits from MusicBrainz' });
    }
});
