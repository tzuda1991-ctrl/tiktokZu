<?php

namespace App\Http\Controllers;

use App\Models\DummyLiveVideos;
use App\Models\GlobalFunction;
use App\Models\GlobalSettings;
use App\Models\Users;
use Illuminate\Http\Request;

class LiveStreamController extends Controller
{
    //
    function dummyLives(){
        $dummyUsers = Users::where('is_dummy', 1)->get();
        return view('dummyLives',[
            'dummyUsers' => $dummyUsers
        ]);
    }

    function addDummyLive(Request $request){
        if (!$request->user_id) {
            return GlobalFunction::sendSimpleResponse(false, 'Please select a Dummy User first!');
        }
        $item = new DummyLiveVideos();
        $item->user_id = $request->user_id;
        $item->title = $request->title;
        $item->link = $request->link;
        $item->status = 1;
        $item->save();

        $this->syncDummyLiveToFirestore($item, false);

        return GlobalFunction::sendSimpleResponse(true, 'Dummy live added successfully');
    }

    function deleteDummyLive(Request $request){
        $item = DummyLiveVideos::find($request->id);
        if ($item) {
            $this->syncDummyLiveToFirestore($item, true);
            $item->delete();
        }

        return GlobalFunction::sendSimpleResponse(true, 'Dummy live deleted successfully');
    }

    function changeDummyLiveStatus(Request $request){
        $coinPackage = DummyLiveVideos::find($request->id);
        if ($coinPackage) {
            $coinPackage->status = $request->status;
            $coinPackage->save();
            $this->syncDummyLiveToFirestore($coinPackage, $coinPackage->status != 1);
        }

        return GlobalFunction::sendSimpleResponse(true, 'Status changed successfully!');
    }

    public function listDummyLives(Request $request)
    {
        DummyLiveVideos::whereNull('user_id')->delete();
        $query = DummyLiveVideos::query();
        $totalData = $query->count();

        $limit = $request->input('length');
        $start = $request->input('start');
        $searchValue = $request->input('search.value');

        if (!empty($searchValue)) {
            $query->where(function ($q) use ($searchValue) {
                $q->where('title', 'LIKE', "%{$searchValue}%")
                ->orwhere('link', 'LIKE', "%{$searchValue}%");
            });
        }
        $totalFiltered = $query->count();

        $result = $query->offset($start)
                        ->limit($limit)
                        ->orderBy('id', 'DESC')
                        ->get();

        $data = $result->map(function ($item){

            $user = GlobalFunction::createUserDetailsColumn($item->user_id);

            $edit = "<a href='#'
                        rel='{$item->id}'
                        data-userid='{$item->user_id}'
                        data-title='{$item->title}'
                        data-link='{$item->link}'
                        class='action-btn edit d-flex align-items-center justify-content-center btn border rounded-2 text-success ms-1'>
                        <i class='uil-pen'></i>
                        </a>";

            $delete = "<a href='#'
                          rel='{$item->id}'
                          class='action-btn delete d-flex align-items-center justify-content-center btn border rounded-2 text-danger ms-1'>
                            <i class='uil-trash-alt'></i>
                        </a>";
            $action = "<span class='d-flex justify-content-end align-items-center'>{$edit}{$delete}</span>";

            $checked = $item->status == 1 ? 'checked' : '';
            $status = "<input type='checkbox' id='dummyLiveStatus-{$item->id}' rel='{$item->id}' class='onOffDummyLive' {$checked} data-switch='none'/>
                    <label for='dummyLiveStatus-{$item->id}'></label>";

            return [
                $user,
                $item->title,
                $item->link,
                $status,
                $action
            ];
        });

        $json_data = [
            "draw" => intval($request->input('draw')),
            "recordsTotal" => intval($totalData),
            "recordsFiltered" => intval($totalFiltered),
            "data" => $data,
        ];

        return response()->json($json_data);
    }

    function editDummyLive(Request $request){
        $dummyLive = DummyLiveVideos::find($request->id);
        if ($dummyLive) {
            $dummyLive->title = $request->title;
            $dummyLive->link = $request->link;
            $dummyLive->save();
            $this->syncDummyLiveToFirestore($dummyLive, $dummyLive->status != 1);
        }

        return GlobalFunction::sendSimpleResponse(true, 'Dummy live updated successfully!');
    }

    private function syncDummyLiveToFirestore($dummyLive, $delete = false)
    {
        try {
            if (!$dummyLive || !$dummyLive->user_id) return;
            $user = Users::find($dummyLive->user_id);
            if (!$user) return;

            $apiKey = 'AIzaSyAb0AAY0VZqO4yvyEIPGNGb6eFktl3c8hk';
            $projectId = 'shortzz-new';

            $authResp = \Illuminate\Support\Facades\Http::post(
                "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={$apiKey}",
                [
                    'email' => 'test_shortzz_google_auth_check@gmail.com',
                    'password' => 'ShortzzGoogleAuth#2026',
                    'returnSecureToken' => true,
                ]
            );
            if (!$authResp->successful()) return;
            $idToken = $authResp->json('idToken');
            if (!$idToken) return;

            $uid = (string) $user->id;
            $baseUrl = "https://firestore.googleapis.com/v1/projects/{$projectId}/databases/(default)/documents";

            if ($delete) {
                \Illuminate\Support\Facades\Http::withToken($idToken)->delete("{$baseUrl}/livestreams/{$uid}/user_state/{$uid}");
                \Illuminate\Support\Facades\Http::withToken($idToken)->delete("{$baseUrl}/livestreams/{$uid}");
                return;
            }

            $nowMs = (string) round(microtime(true) * 1000);

            \Illuminate\Support\Facades\Http::withToken($idToken)->patch("{$baseUrl}/app_users/{$uid}", [
                'fields' => [
                    'user_id' => ['integerValue' => $uid],
                    'identity' => ['stringValue' => (string) ($user->identity ?: $user->username)],
                    'username' => ['stringValue' => (string) $user->username],
                    'fullname' => ['stringValue' => (string) $user->fullname],
                    'profile' => ['stringValue' => (string) ($user->profile_photo ?? '')],
                    'is_verify' => ['integerValue' => (string) intval($user->is_verify)],
                ]
            ]);

            \Illuminate\Support\Facades\Http::withToken($idToken)->patch("{$baseUrl}/livestreams/{$uid}", [
                'fields' => [
                    'watching_count' => ['integerValue' => '0'],
                    'description' => ['stringValue' => trim((string) $dummyLive->title)],
                    'type' => ['stringValue' => 'DUMMY'],
                    'battle_type' => ['stringValue' => 'INITIATE'],
                    'is_restrict_to_join' => ['integerValue' => '1'],
                    'host_view_id' => ['integerValue' => '-1'],
                    'room_id' => ['stringValue' => $uid],
                    'like_count' => ['integerValue' => '0'],
                    'host_id' => ['integerValue' => $uid],
                    'co-host_ids' => ['arrayValue' => (object) []],
                    'created_at' => ['integerValue' => $nowMs],
                    'battle_created_at' => ['nullValue' => null],
                    'is_dummy_live' => ['integerValue' => '1'],
                    'dummy_user_link' => ['stringValue' => (string) $dummyLive->link],
                    'battle_duration' => ['integerValue' => '5'],
                ]
            ]);

            \Illuminate\Support\Facades\Http::withToken($idToken)->patch("{$baseUrl}/livestreams/{$uid}/user_state/{$uid}", [
                'fields' => [
                    'audio_status' => ['stringValue' => 'ON'],
                    'video_status' => ['stringValue' => 'ON'],
                    'type' => ['stringValue' => 'HOST'],
                    'user_id' => ['integerValue' => $uid],
                    'live_coin' => ['integerValue' => '0'],
                    'current_battle_coin' => ['integerValue' => '0'],
                    'total_battle_coin' => ['integerValue' => '0'],
                    'followers_gained' => ['arrayValue' => (object) []],
                    'join_stream_time' => ['integerValue' => $nowMs],
                ]
            ]);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::error('syncDummyLiveToFirestore error: ' . $e->getMessage());
        }
    }
}
